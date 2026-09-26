import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/biometric_denial.dart';
import '../../domain/session_batch_repository.dart';

/// Sealed PIN-screen state for the multi-line batch session-start flow.
@immutable
sealed class BatchAuthState {
  const BatchAuthState();
}

class BatchAuthInitial extends BatchAuthState {
  const BatchAuthInitial();
}

class BatchAuthSubmitting extends BatchAuthState {
  const BatchAuthSubmitting();
}

/// Submission failed. [conflictShiftLineIds] is non-null only for per-line
/// failure codes (`THERMOFORMING_SHIFT_LINE_NOT_FOUND`,
/// `..._LINE_INACTIVE`, `..._LINE_USED_BY_OTHER_WORKER`,
/// `..._LINE_DUPLICATE`) — the picker reads it to drop offending ids.
/// Global codes (`OPERATOR_PIN_INVALID`, `OPERATOR_LOCKED`,
/// `ROLL_WORKER_NOT_ALLOWED`, `..._BATCH_EMPTY`) leave it null and the
/// PIN screen shows an inline error.
class BatchAuthFailure extends BatchAuthState {
  const BatchAuthFailure({
    required this.failure,
    this.conflictShiftLineIds,
  });
  final AppFailure failure;
  final Set<int>? conflictShiftLineIds;
}

/// The PIN was accepted but the biometric gate refused the login (403
/// `BIOMETRIC_*`): the login screen opens the fingerprint dialog. This is not
/// a failure — no wrong-PIN message, no lockout UI.
///
/// [resubmit] re-sends the identical request. It captures the PIN and line
/// ids, so they stay in memory only while this state (and the dialog holding
/// it) is alive; it never touches this controller's state, so the dialog can
/// run several attempts before handing the final outcome to
/// [BatchAuthController.completeBiometricGate].
class BatchAuthBiometricRequired extends BatchAuthState {
  const BatchAuthBiometricRequired({
    required this.denial,
    required this.resubmit,
  });

  final BiometricDenial denial;
  final Future<BatchAuthResult> Function() resubmit;
}

/// Transient terminal state after a successful submit. The controller
/// hands sessions to the registry then resets back to [BatchAuthInitial]
/// so a re-render of the PIN screen starts clean.
class BatchAuthSuccess extends BatchAuthState {
  const BatchAuthSuccess();
}
