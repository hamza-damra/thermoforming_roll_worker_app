import 'package:flutter/foundation.dart';

/// DTO for the response of
/// `GET /shift-lines/{shiftLineId}/roll-worker-session/current`.
///
/// Discovery endpoint — does NOT include `sessionToken`. Used to check
/// whether an active session exists for the shift-line at all.
@immutable
class RollWorkerSessionResponse {
  const RollWorkerSessionResponse({
    required this.sessionId,
    required this.rollWorkerOperatorId,
    required this.rollWorkerName,
    required this.thermoformingShiftId,
    required this.thermoformingShiftLineId,
    required this.thermoformingLineId,
    required this.palletizingLineId,
    required this.status,
    required this.startedAt,
    this.startedAtDisplay,
    this.lastUsedAt,
    this.lastUsedAtDisplay,
  });

  factory RollWorkerSessionResponse.fromJson(Map<String, dynamic> json) {
    final String? startedAtRaw = json['startedAt'] as String?;
    if (startedAtRaw == null) {
      throw const FormatException(
        'RollWorkerSessionResponse: missing required field "startedAt"',
      );
    }
    final String? lastUsedAtRaw = json['lastUsedAt'] as String?;
    return RollWorkerSessionResponse(
      sessionId: (json['sessionId'] as num).toInt(),
      rollWorkerOperatorId: (json['rollWorkerOperatorId'] as num).toInt(),
      rollWorkerName: json['rollWorkerName'] as String,
      thermoformingShiftId: (json['thermoformingShiftId'] as num).toInt(),
      thermoformingShiftLineId: (json['thermoformingShiftLineId'] as num)
          .toInt(),
      thermoformingLineId: (json['thermoformingLineId'] as num).toInt(),
      palletizingLineId: (json['palletizingLineId'] as num).toInt(),
      status: json['status'] as String,
      startedAt: DateTime.parse(startedAtRaw),
      startedAtDisplay: json['startedAtDisplay'] as String?,
      lastUsedAt: lastUsedAtRaw == null ? null : DateTime.parse(lastUsedAtRaw),
      lastUsedAtDisplay: json['lastUsedAtDisplay'] as String?,
    );
  }

  final int sessionId;
  final int rollWorkerOperatorId;
  final String rollWorkerName;
  final int thermoformingShiftId;
  final int thermoformingShiftLineId;
  final int thermoformingLineId;
  final int palletizingLineId;
  final String status;
  final DateTime startedAt;
  final String? startedAtDisplay;
  final DateTime? lastUsedAt;
  final String? lastUsedAtDisplay;
}
