import '../../../core/errors/app_failure.dart';
import 'entities/biometric_attempt_status.dart';

/// Outcome of one attempt-status long-poll. Sealed so the polling loop must
/// handle every branch.
sealed class BiometricStatusResult {
  const BiometricStatusResult();
}

/// 200 — the server answered with a status.
class BiometricStatusAnswered extends BiometricStatusResult {
  const BiometricStatusAnswered(this.response);
  final BiometricAttemptStatusResponse response;
}

/// 410 `BIOMETRIC_LOGIN_ATTEMPT_EXPIRED` — the attempt is unknown or expired.
/// Stop polling; the worker can retry the login.
class BiometricStatusAttemptExpired extends BiometricStatusResult {
  const BiometricStatusAttemptExpired();
}

/// Anything else (timeout, no connection, 5xx, malformed body). Transient:
/// back off and poll again.
class BiometricStatusUnreachable extends BiometricStatusResult {
  const BiometricStatusUnreachable(this.failure);
  final AppFailure failure;
}

abstract class BiometricAttemptRepository {
  /// One long-poll of the attempt identified by [attemptToken]. Never throws.
  ///
  /// [statusPath] is the 403's `details.statusPath`; null or an unsafe value
  /// falls back to the documented path.
  Future<BiometricStatusResult> getStatus({
    required String? statusPath,
    required String attemptToken,
  });
}
