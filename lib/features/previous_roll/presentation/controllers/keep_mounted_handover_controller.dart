import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../data/previous_roll_providers.dart';
import '../../domain/previous_roll_repository.dart';
import 'keep_mounted_handover_state.dart';

/// Drives the keep-mounted handover (the first logout option when a roll is
/// mounted). On success the worker's session is already ended server-side; the
/// caller drops the local session via
/// [MultiLineSessionRegistry.markSessionEndedLocally] and routes to the PIN
/// overlay.
class KeepMountedHandoverController
    extends FamilyNotifier<KeepMountedHandoverState, int> {
  late int _shiftLineId;

  @override
  KeepMountedHandoverState build(int arg) {
    _shiftLineId = arg;
    return const KeepMountedIdle();
  }

  PreviousRollRepository get _repo => ref.read(previousRollRepositoryProvider);

  /// `POST .../previous-roll/keep-mounted-handover`. The caller has already
  /// validated `0 <= remainingWeightKg <= lastKnownWeightKg` locally.
  Future<void> submit(double remainingWeightKg) async {
    if (state is KeepMountedSubmitting) return;
    state = const KeepMountedSubmitting();
    final KeepMountedResult result = await _repo.keepMountedHandover(
      shiftLineId: _shiftLineId,
      remainingWeightKg: remainingWeightKg,
    );
    switch (result) {
      case KeepMountedSuccess(:final response):
        state = KeepMountedSucceeded(response);
      case KeepMountedFailure(:final failure):
        await _onFailure(failure);
    }
  }

  /// Clears any inline error so the worker can retry. Used by the dialog.
  void clearError() {
    if (state is KeepMountedHandoverFailure) {
      state = const KeepMountedIdle();
    }
  }

  Future<void> _onFailure(AppFailure failure) async {
    state = KeepMountedHandoverFailure(failure);
    if (failure is! BusinessFailure) return;
    switch (failure.code) {
      case ErrorCode.rollWorkerSessionRequired:
      case ErrorCode.thermoformingShiftLineNotActive:
      case ErrorCode.thermoformingShiftLineNotFound:
        await ref
            .read(multiLineSessionRegistryProvider.notifier)
            .notifySessionLost(_shiftLineId);
      default:
        break;
    }
  }
}

final keepMountedHandoverControllerProvider =
    NotifierProvider.family<
      KeepMountedHandoverController,
      KeepMountedHandoverState,
      int
    >(KeepMountedHandoverController.new);
