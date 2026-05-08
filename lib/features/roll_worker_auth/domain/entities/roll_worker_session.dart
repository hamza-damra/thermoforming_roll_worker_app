import 'package:flutter/foundation.dart';

/// Active roll-worker session, scoped to a single Thermoforming shift-line.
///
/// **Never** carries the raw `sessionToken`. The token is persisted at login
/// time by the repository and lives only inside [SecureTokenStorage]; the UI
/// must not see it.
@immutable
class RollWorkerSession {
  const RollWorkerSession({
    required this.sessionId,
    required this.rollWorkerOperatorId,
    required this.rollWorkerName,
    required this.thermoformingShiftId,
    required this.thermoformingShiftLineId,
    required this.thermoformingLineId,
    required this.palletizingLineId,
    required this.startedAt,
    this.startedAtDisplay,
    this.lastUsedAt,
    this.lastUsedAtDisplay,
    this.status,
  });

  final int sessionId;
  final int rollWorkerOperatorId;
  final String rollWorkerName;
  final int thermoformingShiftId;
  final int thermoformingShiftLineId;
  final int thermoformingLineId;
  final int palletizingLineId;
  final DateTime startedAt;
  final String? startedAtDisplay;
  final DateTime? lastUsedAt;
  final String? lastUsedAtDisplay;

  /// Backend-side session status (e.g. `ACTIVE`). Available on the
  /// session-current response; null on the auth response.
  final String? status;

  /// Whether the session is in the active state per the backend.
  bool get isActive => status == null || status == 'ACTIVE';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RollWorkerSession &&
        other.sessionId == sessionId &&
        other.rollWorkerOperatorId == rollWorkerOperatorId &&
        other.rollWorkerName == rollWorkerName &&
        other.thermoformingShiftId == thermoformingShiftId &&
        other.thermoformingShiftLineId == thermoformingShiftLineId &&
        other.thermoformingLineId == thermoformingLineId &&
        other.palletizingLineId == palletizingLineId &&
        other.startedAt == startedAt &&
        other.startedAtDisplay == startedAtDisplay &&
        other.lastUsedAt == lastUsedAt &&
        other.lastUsedAtDisplay == lastUsedAtDisplay &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    rollWorkerOperatorId,
    rollWorkerName,
    thermoformingShiftId,
    thermoformingShiftLineId,
    thermoformingLineId,
    palletizingLineId,
    startedAt,
    startedAtDisplay,
    lastUsedAt,
    lastUsedAtDisplay,
    status,
  );
}
