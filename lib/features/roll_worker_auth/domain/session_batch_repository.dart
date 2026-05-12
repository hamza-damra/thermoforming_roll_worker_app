import '../../../core/errors/app_failure.dart';
import 'entities/batch_auth_outcome.dart';

/// Outcome of a batch session-start. Sealed so the controller layer must
/// handle both branches via an exhaustive switch.
sealed class BatchAuthResult {
  const BatchAuthResult();
}

class BatchAuthSuccessResult extends BatchAuthResult {
  const BatchAuthSuccessResult(this.outcome);
  final BatchAuthOutcome outcome;
}

class BatchAuthFailureResult extends BatchAuthResult {
  const BatchAuthFailureResult(this.failure, {this.conflictShiftLineIds});

  final AppFailure failure;

  /// Per-line ids extracted from `BusinessFailure.details.shiftLineId` for
  /// codes that identify a specific offending line
  /// (`THERMOFORMING_SHIFT_LINE_NOT_FOUND`, `..._LINE_INACTIVE`,
  /// `..._LINE_USED_BY_OTHER_WORKER`, `..._LINE_DUPLICATE`). Null when the
  /// failure is global (`OPERATOR_PIN_INVALID`, `OPERATOR_LOCKED`,
  /// `ROLL_WORKER_NOT_ALLOWED`, `..._BATCH_EMPTY`).
  final Set<int>? conflictShiftLineIds;
}

/// Repository contract for the multi-line atomic session-start.
///
/// On success the implementation has already persisted the per-line raw
/// session tokens to [SecureTokenStorage] and the active-shift-line index
/// to [SessionIndexStorage]; the controller layer never sees the raw
/// tokens.
abstract class SessionBatchRepository {
  /// Validates [pin] once and atomically opens (or replaces) one ACTIVE
  /// session per id in [shiftLineIds]. Any error rejects the whole batch
  /// — no session is opened on any line.
  Future<BatchAuthResult> startBatch({
    required String pin,
    required Set<int> shiftLineIds,
  });
}
