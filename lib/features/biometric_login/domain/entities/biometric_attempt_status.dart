import 'package:flutter/foundation.dart';

/// `data.status` of `GET /api/v1/auth/biometric/login-attempts/status`
/// (biometric handoff §4.3).
enum BiometricAttemptStatus {
  /// No valid fingerprint yet — poll again immediately.
  pending,

  /// A valid fingerprint arrived — re-submit the original login once.
  verified,

  /// The factory agent is offline, so the check is suspended — re-submit.
  enforcementSuspended,

  /// An admin exempted the worker or switched the check off — re-submit.
  notRequired,

  /// The terminal reports offline while the agent is up — keep polling.
  deviceUnavailable,

  /// The admin removed the terminal link meanwhile — stop, contact admin.
  mappingMissing,

  /// The admin disabled the terminal link meanwhile — stop, contact admin.
  mappingDisabled;

  /// Unknown or missing values map to [pending] so a future server value
  /// never crashes the dialog.
  static BiometricAttemptStatus fromWire(Object? raw) => switch (raw) {
    'VERIFIED' => verified,
    'ENFORCEMENT_SUSPENDED' => enforcementSuspended,
    'NOT_REQUIRED' => notRequired,
    'DEVICE_UNAVAILABLE' => deviceUnavailable,
    'MAPPING_MISSING' => mappingMissing,
    'MAPPING_DISABLED' => mappingDisabled,
    _ => pending,
  };
}

@immutable
class BiometricAttemptStatusResponse {
  const BiometricAttemptStatusResponse({
    required this.status,
    this.attemptExpiresAt,
  });

  final BiometricAttemptStatus status;

  /// UTC. Informational only — expiry is decided by the server's 410, never
  /// by the device clock.
  final DateTime? attemptExpiresAt;
}
