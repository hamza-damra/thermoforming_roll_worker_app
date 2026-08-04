import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/errors/failure_classification.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_controller.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../data/previous_roll_providers.dart';
import '../../domain/previous_roll_repository.dart';
import 'previous_roll_resolution_state.dart';

class PreviousRollResolutionController
    extends FamilyNotifier<PreviousRollResolutionState, int> {
  late int _shiftLineId;

  @override
  PreviousRollResolutionState build(int arg) {
    _shiftLineId = arg;
    return const PreviousRollIdle();
  }

  PreviousRollRepository get _repo => ref.read(previousRollRepositoryProvider);

  /// `POST .../previous-roll/full-consume`.
  Future<void> fullConsume() async {
    if (state is PreviousRollResolving) return;
    state = const PreviousRollResolving();
    final PreviousRollResult result = await _repo.fullConsume(
      shiftLineId: _shiftLineId,
    );
    await _handle(result);
  }

  /// `POST .../previous-roll/return` — caller has already validated
  /// `>= 0` and `<= activeSegment startWeight` against the mount card's
  /// `lastKnownWeightKg`, and that [reasonText] is non-blank (V127).
  Future<void> returnRemaining(
    double remainingWeightKg,
    String reasonText,
  ) async {
    if (state is PreviousRollResolving) return;
    state = const PreviousRollResolving();
    final PreviousRollResult result = await _repo.returnRemaining(
      shiftLineId: _shiftLineId,
      remainingWeightKg: remainingWeightKg,
      reasonText: reasonText,
    );
    await _handle(result);
  }

  /// `POST .../previous-roll/grinding` with a required [reasonText] (V127).
  Future<void> sendToGrinding(
    double remainingWeightKg,
    String reasonText,
  ) async {
    if (state is PreviousRollResolving) return;
    state = const PreviousRollResolving();
    final PreviousRollResult result = await _repo.sendToGrinding(
      shiftLineId: _shiftLineId,
      remainingWeightKg: remainingWeightKg,
      reasonText: reasonText,
    );
    await _handle(result);
  }

  /// Worker dismissed the post-close summary. Move back to idle so the
  /// home re-exposes the empty mount CTA.
  void acknowledge() {
    if (state is PreviousRollResolved) {
      state = const PreviousRollIdle();
    }
  }

  /// Clears any inline error so the worker can retry. Used by dialogs.
  void clearError() {
    if (state is PreviousRollFailureState) {
      state = const PreviousRollIdle();
    }
  }

  /// Drops any cached resolution. Called on logout.
  void reset() {
    state = const PreviousRollIdle();
  }

  Future<void> _handle(PreviousRollResult result) async {
    switch (result) {
      case PreviousRollSuccess(:final resolution):
        // Mount is closed on the backend. Reset the local mount cache so
        // the home re-exposes the empty mount CTA after the summary card
        // is dismissed.
        ref.read(rollScanControllerProvider(_shiftLineId).notifier).reset();
        state = PreviousRollResolved(resolution);
      case PreviousRollFailure(:final failure):
        await _onFailure(failure);
    }
  }

  Future<void> _onFailure(AppFailure failure) async {
    state = PreviousRollFailureState(failure);

    // A device-key fault is excluded by `isSessionLossCascade` — it leaves the
    // session valid, so it must not funnel the worker back to the PIN overlay.
    if (isSessionLossCascade(failure)) {
      await ref
          .read(multiLineSessionRegistryProvider.notifier)
          .notifySessionLost(_shiftLineId);
      return;
    }
    if (failure is BusinessFailure &&
        failure.code == ErrorCode.noActiveRollOnLine) {
      // Server says nothing is mounted — drop the local mount cache so
      // the home re-exposes the empty mount CTA.
      ref.read(rollScanControllerProvider(_shiftLineId).notifier).reset();
    }
  }
}

final previousRollResolutionControllerProvider =
    NotifierProvider.family<
      PreviousRollResolutionController,
      PreviousRollResolutionState,
      int
    >(PreviousRollResolutionController.new);
