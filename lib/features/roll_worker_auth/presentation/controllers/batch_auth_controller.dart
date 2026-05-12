import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../data/roll_worker_auth_providers.dart';
import '../../domain/session_batch_repository.dart';
import 'batch_auth_state.dart';
import 'multi_line_session_registry.dart';

/// Drives the PIN screen for the multi-line batch session-start flow.
///
/// On success, hands the per-line sessions to
/// [MultiLineSessionRegistry] (which persists them and seeds the home
/// shell) then resets to [BatchAuthInitial] so a re-render of the PIN
/// screen starts clean. On failure, retains the failure on state so the
/// PIN screen can render an inline error or the picker can read
/// `conflictShiftLineIds` after a Navigator pop.
class BatchAuthController extends Notifier<BatchAuthState> {
  @override
  BatchAuthState build() => const BatchAuthInitial();

  SessionBatchRepository get _repo => ref.read(sessionBatchRepositoryProvider);

  /// Submits [pin] against [shiftLineIds]. Idempotent against double-tap:
  /// the second call while a submission is in flight is a no-op.
  Future<void> submit(String pin, Set<int> shiftLineIds) async {
    if (state is BatchAuthSubmitting) return;
    if (shiftLineIds.isEmpty) {
      state = const BatchAuthFailure(
        failure: BusinessFailure(code: ErrorCode.rollWorkerSessionBatchEmpty),
      );
      return;
    }
    if (pin.isEmpty) {
      state = const BatchAuthFailure(
        failure: BusinessFailure(code: ErrorCode.operatorPinInvalid),
      );
      return;
    }

    state = const BatchAuthSubmitting();

    final BatchAuthResult result = await _repo.startBatch(
      pin: pin,
      shiftLineIds: shiftLineIds,
    );
    switch (result) {
      case BatchAuthSuccessResult(:final outcome):
        await ref
            .read(multiLineSessionRegistryProvider.notifier)
            .onBatchSuccess(outcome.sessions);
        state = const BatchAuthSuccess();
      case BatchAuthFailureResult(:final failure, :final conflictShiftLineIds):
        state = BatchAuthFailure(
          failure: failure,
          conflictShiftLineIds: conflictShiftLineIds,
        );
    }
  }

  /// Clears any prior failure when the PIN screen is dismissed without a
  /// fresh submit.
  void reset() {
    state = const BatchAuthInitial();
  }
}

final NotifierProvider<BatchAuthController, BatchAuthState>
batchAuthControllerProvider =
    NotifierProvider<BatchAuthController, BatchAuthState>(
      BatchAuthController.new,
    );
