import '../../../core/errors/app_failure.dart';
import 'entities/roll_worker_session.dart';

/// Outcome of an auth operation. Repositories return one of these instead of
/// throwing — controllers map to UI states.
sealed class RollWorkerAuthResult {
  const RollWorkerAuthResult();
}

class RollWorkerAuthSuccess extends RollWorkerAuthResult {
  const RollWorkerAuthSuccess(this.session);
  final RollWorkerSession session;
}

class RollWorkerAuthFailure extends RollWorkerAuthResult {
  const RollWorkerAuthFailure(this.failure);
  final AppFailure failure;
}

/// Repository contract for per-shift-line roll-worker session restore +
/// logout. PIN authentication lives on [SessionBatchRepository]; this
/// interface only exposes the read-only discovery + logout endpoints.
abstract class RollWorkerAuthRepository {
  /// Asks the backend for the current session on [shiftLineId]. Discovery
  /// mode — does NOT require a session token to be present.
  Future<RollWorkerAuthResult> getCurrentSession(int shiftLineId);

  /// Logs out and clears the locally stored session token for
  /// [shiftLineId]. Idempotent.
  Future<void> logout(int shiftLineId);

  /// Reads the locally stored token, if any. Used by repositories of other
  /// features (scan, previous-roll, etc.) to attach it to outgoing
  /// requests.
  Future<String?> readStoredToken(int shiftLineId);

  /// Clears the locally stored token without making a network call. Used on
  /// `ROLL_WORKER_SESSION_REQUIRED` cascade-on-end paths.
  Future<void> clearStoredToken(int shiftLineId);
}
