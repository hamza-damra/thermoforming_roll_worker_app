import 'package:flutter/foundation.dart';

import 'app_failure.dart';
import 'error_code.dart';

/// A login refused by the biometric gate (HTTP 403, `error.code` starting with
/// `BIOMETRIC_`), parsed from the failure envelope's `error.details`.
///
/// See `docs/FRONTEND_HANDOFF_ROLL_WORKER_APP_BIOMETRIC_LOGIN_GATE.md` §4.2.
///
/// [attemptToken] is a **secret**: it lives in memory only, for the life of
/// the fingerprint dialog. It is never logged ([toString] redacts it), never
/// persisted, never shown and never put in a URL — it travels only in the
/// `X-Biometric-Attempt-Token` header of the status long-poll.
@immutable
class BiometricDenial {
  const BiometricDenial({
    required this.code,
    required this.message,
    required this.validitySeconds,
    required this.attemptAvailable,
    this.attemptToken,
    this.attemptExpiresAt,
    this.statusPath,
  });

  /// Parses `error.details` defensively: a missing or wrongly typed entry
  /// collapses to its safe default instead of throwing.
  factory BiometricDenial.fromEnvelope({
    required String code,
    required String message,
    Map<String, Object?>? details,
  }) {
    final Object? token = details?['attemptToken'];
    final String? attemptToken = token is String && token.isNotEmpty
        ? token
        : null;
    final Object? available = details?['attemptAvailable'];
    final Object? validity = details?['validitySeconds'];
    final Object? expiresAt = details?['attemptExpiresAt'];
    final Object? path = details?['statusPath'];
    return BiometricDenial(
      code: code,
      message: message,
      validitySeconds: validity is num ? validity.toInt() : 0,
      attemptAvailable: available is bool ? available : attemptToken != null,
      attemptToken: attemptToken,
      attemptExpiresAt: expiresAt is String
          ? DateTime.tryParse(expiresAt)?.toUtc()
          : null,
      statusPath: path is String && path.isNotEmpty ? path : null,
    );
  }

  /// Wire prefix shared by every biometric gate code.
  static const String codePrefix = 'BIOMETRIC_';

  /// True for a login-refusal code — any `BIOMETRIC_*` code except the
  /// status endpoint's 410 [ErrorCode.biometricLoginAttemptExpired]. Unknown
  /// future `BIOMETRIC_*` codes count, so a new server reason still opens the
  /// dialog instead of reading as a generic error.
  static bool isDenialCode(String? wireCode) =>
      wireCode != null &&
      wireCode.startsWith(codePrefix) &&
      wireCode != ErrorCode.biometricLoginAttemptExpired.wireValue;

  /// `error.code` exactly as the server sent it.
  final String code;

  /// `error.message` — Arabic, displayed as-is.
  final String message;

  final int validitySeconds;
  final bool attemptAvailable;

  /// Secret — see the class doc.
  final String? attemptToken;

  /// UTC. Not used for any expiry decision: the device clock may be wrong, so
  /// the status endpoint's 410 is the only authority on expiry.
  final DateTime? attemptExpiresAt;

  /// `details.statusPath`, resolved against the login's base URL.
  final String? statusPath;

  ErrorCode get errorCode => ErrorCode.fromWire(code);

  /// `BIOMETRIC_MAPPING_MISSING` / `_DISABLED`: only a SYSTEM_ADMIN can fix
  /// these, so the dialog neither polls nor retries.
  bool get isMappingProblem =>
      errorCode == ErrorCode.biometricMappingMissing ||
      errorCode == ErrorCode.biometricMappingDisabled;

  bool get isDeviceUnavailable =>
      errorCode == ErrorCode.biometricDeviceUnavailable;

  /// Whether there is an attempt to long-poll. False when the server could
  /// not record one (`attemptAvailable: false`) — the dialog then asks the
  /// worker to scan and retry.
  bool get hasAttempt =>
      attemptAvailable && attemptToken != null && !isMappingProblem;

  /// A copy with no attempt, safe to keep after the dialog closes.
  BiometricDenial withoutAttempt() => BiometricDenial(
    code: code,
    message: message,
    validitySeconds: validitySeconds,
    attemptAvailable: false,
  );

  @override
  String toString() =>
      'BiometricDenial(code: $code, attemptAvailable: $attemptAvailable, '
      'attemptToken: ${attemptToken == null ? 'null' : '<redacted>'})';
}

/// [BusinessFailure] for a biometric login refusal. It is still a
/// `BusinessFailure`, so every existing switch keeps working; the login flow
/// matches this subtype to open the fingerprint dialog instead of showing an
/// inline error.
///
/// `details` is deliberately left null on the base class: the raw map carries
/// the attempt token and [BusinessFailure.toString] prints `details`. The
/// parsed values live on [denial], whose own `toString` redacts the token.
class BiometricDenialFailure extends BusinessFailure {
  BiometricDenialFailure({required this.denial, super.statusCode})
    : super(code: ErrorCode.fromWire(denial.code), serverMessage: denial.message);

  final BiometricDenial denial;

  @override
  String toString() =>
      'BiometricDenialFailure(code: ${denial.code}, statusCode: $statusCode, '
      'attemptAvailable: ${denial.attemptAvailable})';
}
