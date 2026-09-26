import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/biometric_denial.dart';
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
///
/// A biometric refusal becomes [BatchAuthBiometricRequired]; the login screen
/// runs the fingerprint dialog and reports its final outcome through
/// [completeBiometricGate].
class BatchAuthController extends Notifier<BatchAuthState> {
  @override
  BatchAuthState build() => const BatchAuthInitial();

  SessionBatchRepository get _repo => ref.read(sessionBatchRepositoryProvider);

  /// Submits [pin] against [shiftLineIds]. Idempotent against double-tap:
  /// a call while a submission is in flight, or while its fingerprint dialog
  /// is open, is a no-op — only one biometric attempt may be active.
  Future<void> submit(String pin, Set<int> shiftLineIds) async {
    if (state is BatchAuthSubmitting || state is BatchAuthBiometricRequired) {
      return;
    }
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

    final Set<int> ids = Set<int>.unmodifiable(shiftLineIds);
    final BatchAuthResult result = await _repo.startBatch(
      pin: pin,
      shiftLineIds: ids,
    );
    if (result case BatchAuthFailureResult(
      failure: final BiometricDenialFailure denied,
    )) {
      // Not a wrong PIN: open the fingerprint dialog. Its resubmit re-sends
      // the identical body — the PIN lives only in this closure.
      state = BatchAuthBiometricRequired(
        denial: denied.denial,
        resubmit: () => _repo.startBatch(pin: pin, shiftLineIds: ids),
      );
      return;
    }
    await _apply(result);
  }

  /// Hands the fingerprint dialog's final outcome back: the resubmitted
  /// login's success or failure, a contact-admin failure, or null when the
  /// worker cancelled. Never re-enters [BatchAuthBiometricRequired] — the
  /// dialog already handled every biometric answer it received.
  Future<void> completeBiometricGate(BatchAuthResult? result) async {
    if (result == null) {
      state = const BatchAuthInitial();
      return;
    }
    await _apply(result);
  }

  Future<void> _apply(BatchAuthResult result) async {
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
  /// fresh submit. Also drops a [BatchAuthBiometricRequired] whose dialog
  /// never opened (its screen went away mid-submit), so the next login is not
  /// blocked; an open dialog keeps its own copy of the attempt and reports
  /// back through [completeBiometricGate] regardless.
  void reset() {
    state = const BatchAuthInitial();
  }
}

final NotifierProvider<BatchAuthController, BatchAuthState>
batchAuthControllerProvider =
    NotifierProvider<BatchAuthController, BatchAuthState>(
      BatchAuthController.new,
    );
