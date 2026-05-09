import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/errors/error_messages_ar.dart';
import '../../../printer/core/printing_constants.dart';
import '../../../printer/core/printing_exception.dart';
import '../../../printer/data/printer_providers.dart';
import '../../../printer/data/printing_local_storage.dart';
import '../../../printer/domain/entities/label_preset.dart';
import '../../../printer/domain/entities/printer_config.dart';
import '../../../printer/pipeline/printer_transport.dart';
import '../../../roll_worker_auth/presentation/controllers/roll_worker_auth_controller.dart';
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
  /// reprint button.
  Future<void> reprint(String generatedRollId) async {
    if (state is LabelReprintFetching || state is LabelReprintPrinting) {
      return;
    }
    final RollLabel? label = await _fetch(generatedRollId);
    if (label == null) return; // _fetch already set Failure state
    await _print(label, generatedRollId);
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

  Future<void> _print(RollLabel label, String generatedRollId) async {
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
          ? DefaultPresets.preset50x30
          : ref.read(presetRepositoryProvider).getById(presetId) ??
                DefaultPresets.preset50x30;

      final int storedCopies = PrintingLocalStorage.getSettings().copies;
      final int copyCount = storedCopies <= 0
          ? PrintingConstants.defaultCopies
          : storedCopies;

      await _transport.sendPrintJob(
        printer: printer,
        value: label.generatedRollId,
        preset: preset,
        copies: copyCount,
        topText: label.rollTypeRollCode,
        bottomText: label.rollTypeDisplayName,
        sideText: label.generatedRollId,
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
    if (failure is BusinessFailure &&
        failure.code == ErrorCode.rollWorkerSessionRequired) {
      // Cascade snackbar fires via the bootstrap listener.
      await ref
          .read(rollWorkerAuthControllerProvider(_shiftLineId).notifier)
          .notifySessionLost();
    }
  }
}

final labelReprintControllerProvider =
    NotifierProvider.family<LabelReprintController, LabelReprintState, int>(
      LabelReprintController.new,
    );
