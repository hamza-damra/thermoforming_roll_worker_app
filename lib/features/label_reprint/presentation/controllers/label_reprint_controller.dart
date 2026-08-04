import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_classification.dart';
import '../../../../core/errors/error_messages_ar.dart';
import '../../../printer/core/printing_constants.dart';
import '../../../printer/core/printing_exception.dart';
import '../../../printer/data/printer_providers.dart';
import '../../../printer/data/printing_local_storage.dart';
import '../../../printer/domain/entities/label_preset.dart';
import '../../../printer/domain/entities/printer_config.dart';
import '../../../printer/domain/entities/roll_label_data.dart';
import '../../../printer/pipeline/printer_transport.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../data/label_reprint_providers.dart';
import '../../domain/entities/roll_label.dart';
import '../../domain/label_reprint_repository.dart';
import 'label_reprint_state.dart';

/// Orchestrates the full reprint pipeline: backend `GET /reprint-label`
/// → resolve default printer + preset → send TSPL job over TCP.
///
/// Production flow: tap reprint → controller fires this end-to-end with
/// no preview gate. The blocking dialog reads [state]; on
/// [LabelReprintFailureState] the worker can retry the failed stage.
class LabelReprintController extends FamilyNotifier<LabelReprintState, int> {
  late int _shiftLineId;

  @override
  LabelReprintState build(int arg) {
    _shiftLineId = arg;
    return const LabelReprintIdle();
  }

  LabelReprintRepository get _repo => ref.read(labelReprintRepositoryProvider);
  PrinterTransport get _transport => ref.read(printerTransportProvider);

  /// Full pipeline (fetch + immediate physical print). Used by the home
  /// reprint button and by the post-close auto-print path.
  ///
  /// [overrideTimestamp] — optional backend-authoritative timestamp from a
  /// fresher source than `/reprint-label.createdAt`. Priority chain:
  ///   1. `overrideTimestamp` (e.g. `consumedRoll.labelTimestamp` from
  ///      `/summary`, or the close response's `labelTimestamp`)
  ///   2. The fetched `RollLabel.createdAt`
  ///   3. **Abort** with [PrintingException.missingLabelTimestamp]. The
  ///      controller never substitutes device time.
  ///
  /// [labelType] — `'RETURN_REMAINING'` | `'GRINDING_REMAINING'` from the
  /// backend. `'GRINDING_REMAINING'` switches on the reference scrap
  /// icon; other values use the standard layout.
  Future<void> reprint(
    String generatedRollId, {
    DateTime? overrideTimestamp,
    String? labelType,
  }) async {
    if (state is LabelReprintFetching || state is LabelReprintPrinting) {
      return;
    }
    final RollLabel? label = await _fetch(generatedRollId);
    if (label == null) return; // _fetch already set Failure state
    await _print(
      label,
      generatedRollId,
      overrideTimestamp: overrideTimestamp,
      labelType: labelType,
    );
  }

  /// Fetch only. Used by the secondary preview screen so the worker can
  /// inspect the canonical payload before deciding to print.
  Future<void> previewOnly(String generatedRollId) async {
    if (state is LabelReprintFetching) return;
    final RollLabel? label = await _fetch(generatedRollId);
    if (label == null) return;
    state = LabelReprintReady(label);
  }

  /// Sends the cached label to the printer without re-fetching. Used by
  /// the preview screen's print button when state is already
  /// [LabelReprintReady].
  Future<void> printAlreadyFetched() async {
    if (state is LabelReprintPrinting) return;
    final LabelReprintState s = state;
    if (s is! LabelReprintReady) return;
    await _print(s.label, s.label.generatedRollId);
  }

  /// Re-runs whichever stage just failed. Re-fetches when no cached label
  /// is available, or re-sends when one is.
  Future<void> retry() async {
    final LabelReprintState s = state;
    if (s is! LabelReprintFailureState) return;
    if (s.cachedLabel != null) {
      await _print(s.cachedLabel!, s.generatedRollId);
    } else {
      final RollLabel? label = await _fetch(s.generatedRollId);
      if (label == null) return;
      await _print(label, s.generatedRollId);
    }
  }

  /// Worker dismissed the dialog. Resets to Idle so the next reprint
  /// starts clean.
  void cancel() {
    state = const LabelReprintIdle();
  }

  /// Drops any cached label. Called on logout.
  void reset() {
    state = const LabelReprintIdle();
  }

  // ─── internals ──────────────────────────────────────────────────────────

  /// Returns the fetched label or null if the fetch failed (in which case
  /// state is already a [LabelReprintFailureState]). Also handles the
  /// session-loss cascade.
  Future<RollLabel?> _fetch(String generatedRollId) async {
    state = const LabelReprintFetching();
    final LabelReprintResult result = await _repo.fetchLabel(
      shiftLineId: _shiftLineId,
      generatedRollId: generatedRollId,
    );
    switch (result) {
      case LabelReprintSuccess(:final label):
        return label;
      case LabelReprintFailureResult(:final failure):
        await _onFetchFailure(failure, generatedRollId);
        return null;
    }
  }

  Future<void> _print(
    RollLabel label,
    String generatedRollId, {
    DateTime? overrideTimestamp,
    String? labelType,
  }) async {
    state = LabelReprintPrinting(label);
    try {
      final PrinterConfig? printer = ref
          .read(printerRepositoryProvider)
          .getDefault();
      if (printer == null) {
        throw PrintingException.noPrinterSelected();
      }

      final String? presetId =
          PrintingLocalStorage.getSettings().selectedPresetId;
      final LabelPreset preset = presetId == null
          ? DefaultPresets.preset100x100
          : ref.read(presetRepositoryProvider).getById(presetId) ??
                DefaultPresets.preset100x100;

      final int storedCopies = PrintingLocalStorage.getSettings().copies;
      final int copyCount = storedCopies <= 0
          ? PrintingConstants.defaultCopies
          : storedCopies;

      // Strict timestamp resolution — never substitute device time.
      // Priority: override (e.g. summary.labelTimestamp / close response)
      //        → fetched RollLabel.createdAt
      //        → abort.
      final DateTime? resolvedTimestamp =
          overrideTimestamp ?? label.createdAt;
      if (resolvedTimestamp == null) {
        throw PrintingException.missingLabelTimestamp();
      }

      // GRINDING_REMAINING → paint the reference's scrap icon next to the
      // serial. Other types (RETURN_REMAINING, null) keep the standard
      // layout — no banner is added, mirroring the RollProductionApp
      // reference (which has no return-specific marker).
      final bool isScrap = labelType == 'GRINDING_REMAINING';

      final RollLabelData labelData = RollLabelData.fromParts(
        generatedRollId: label.generatedRollId,
        rollTypeRollCode: label.rollTypeRollCode,
        isScrap: isScrap,
        createdAt: resolvedTimestamp,
      );

      await _transport.sendPrintJob(
        printer: printer,
        value: label.generatedRollId,
        preset: preset,
        copies: copyCount,
        labelData: labelData,
      );
      state = LabelReprintSent(label);
    } on PrintingException catch (e) {
      state = LabelReprintFailureState(
        message: e.displayMessage,
        generatedRollId: generatedRollId,
        cachedLabel: label,
      );
    } catch (e) {
      state = LabelReprintFailureState(
        message: PrintingException.sendFailed(error: e).displayMessage,
        generatedRollId: generatedRollId,
        cachedLabel: label,
      );
    }
  }

  Future<void> _onFetchFailure(
    AppFailure failure,
    String generatedRollId,
  ) async {
    state = LabelReprintFailureState(
      message: arabicMessageFor(failure),
      generatedRollId: generatedRollId,
    );
    // Drop this line ONLY on the authoritative per-line end signals (handoff
    // §7) — the same three codes every other per-line controller (scan,
    // previous-roll, summary) treats as "this exact
    // line ended". A reprint returning NOT_ACTIVE / NOT_FOUND for this
    // shift-line is the backend confirming the line is gone, so the registry
    // entry must be released too (it previously lingered as a zombie line).
    if (isSessionLossCascade(failure)) {
      // Cascade snackbar fires via the bootstrap listener.
      await ref
          .read(multiLineSessionRegistryProvider.notifier)
          .notifySessionLost(_shiftLineId);
    }
  }
}

final labelReprintControllerProvider =
    NotifierProvider.family<LabelReprintController, LabelReprintState, int>(
      LabelReprintController.new,
    );
