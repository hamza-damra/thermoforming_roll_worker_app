import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../roll_worker_auth/presentation/controllers/roll_worker_auth_controller.dart';
import '../../../shift_line/presentation/controllers/selected_shift_line_provider.dart';
import '../../data/roll_scan_providers.dart';
import '../../domain/entities/mounted_roll.dart';
import '../../domain/roll_scan_repository.dart';
import 'roll_scan_state.dart';

class RollScanController extends FamilyNotifier<RollScanState, int> {
  late int _shiftLineId;

  /// 12-digit `PPPSSSSSSSSS` validation per requirements §9.
  static final RegExp _generatedRollIdPattern = RegExp(r'^\d{12}$');

  static bool isValidGeneratedRollId(String value) =>
      _generatedRollIdPattern.hasMatch(value);

  @override
  RollScanState build(int arg) {
    _shiftLineId = arg;
    return const RollScanIdle();
  }

  RollScanRepository get _repo => ref.read(rollScanRepositoryProvider);

  /// Submits a generatedRollId to the backend. Idempotent against rapid
  /// double-taps (suppressed while in [RollScanSubmitting]).
  Future<void> mountRoll(String generatedRollId) async {
    if (state is RollScanSubmitting) return;

    // Snapshot before mutating state so a failed retry can fall back to the
    // previously mounted roll on the home card.
    final MountedRoll? snapshot = _previouslyMounted;

    final String trimmed = generatedRollId.trim();
    if (!isValidGeneratedRollId(trimmed)) {
      // Treat malformed client-side input as a roll-not-found inline error
      // rather than firing the network call.
      state = RollScanFailureState(
        failure: const BusinessFailure(code: ErrorCode.rollNotFound),
        previous: snapshot,
      );
      return;
    }

    state = const RollScanSubmitting();
    final RollScanResult result = await _repo.mountRoll(
      shiftLineId: _shiftLineId,
      generatedRollId: trimmed,
    );
    switch (result) {
      case RollScanSuccess(:final mounted):
        state = RollScanMounted(mounted);
      case RollScanFailure(:final failure):
        await _onFailure(failure, previous: snapshot);
    }
  }

  /// Clears a transient inline error so the worker can retry. Preserves any
  /// previously-mounted roll on the home screen.
  void clearError() {
    if (state case RollScanFailureState(:final previous)) {
      state = previous == null
          ? const RollScanIdle()
          : RollScanMounted(previous);
    }
  }

  /// Drops any locally cached mount. Called on logout.
  void reset() {
    state = const RollScanIdle();
  }

  MountedRoll? get _previouslyMounted {
    return switch (state) {
      RollScanMounted(:final roll) => roll,
      RollScanFailureState(:final previous) => previous,
      _ => null,
    };
  }

  Future<void> _onFailure(
    AppFailure failure, {
    required MountedRoll? previous,
  }) async {
    state = RollScanFailureState(failure: failure, previous: previous);

    if (failure is! BusinessFailure) return;
    switch (failure.code) {
      case ErrorCode.rollWorkerSessionRequired:
        // Auth controller handles token-clear + cascade snackbar wiring.
        await ref
            .read(rollWorkerAuthControllerProvider(_shiftLineId).notifier)
            .notifySessionLost();
      case ErrorCode.thermoformingShiftLineNotActive:
      case ErrorCode.thermoformingShiftLineNotFound:
        // Drop back to the waiting screen and let the bootstrap snackbar
        // surface the cascade message via the auth controller.
        await ref
            .read(rollWorkerAuthControllerProvider(_shiftLineId).notifier)
            .notifySessionLost();
        ref.read(selectedShiftLineIdProvider.notifier).clear();
      default:
        break;
    }
  }
}

final rollScanControllerProvider =
    NotifierProvider.family<RollScanController, RollScanState, int>(
      RollScanController.new,
    );
