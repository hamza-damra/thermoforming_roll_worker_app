import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';

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

/// Transient terminal state after a successful submit. The controller
/// hands sessions to the registry then resets back to [BatchAuthInitial]
/// so a re-render of the PIN screen starts clean.
class BatchAuthSuccess extends BatchAuthState {
  const BatchAuthSuccess();
}
