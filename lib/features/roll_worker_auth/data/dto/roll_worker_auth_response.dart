import 'package:flutter/foundation.dart';

/// DTO for the response of `POST /shift-lines/{shiftLineId}/roll-worker-auth`.
///
/// Critical: this is the ONLY response that carries the raw [sessionToken].
/// Backend stores only its SHA-256 hash, so the app must persist this raw
/// value to its secure store immediately, then drop it from in-memory state.
@immutable
class RollWorkerAuthResponse {
  const RollWorkerAuthResponse({
    required this.sessionId,
    required this.sessionToken,
    required this.rollWorkerOperatorId,
    required this.rollWorkerName,
    required this.thermoformingShiftId,
    required this.thermoformingShiftLineId,
    required this.thermoformingLineId,
    required this.palletizingLineId,
    required this.startedAt,
    this.startedAtDisplay,
  });

  factory RollWorkerAuthResponse.fromJson(Map<String, dynamic> json) {
    final String? startedAtRaw = json['startedAt'] as String?;
    if (startedAtRaw == null) {
      throw const FormatException(
        'RollWorkerAuthResponse: missing required field "startedAt"',
      );
    }
    final String? token = json['sessionToken'] as String?;
    if (token == null || token.isEmpty) {
      throw const FormatException(
        'RollWorkerAuthResponse: missing required field "sessionToken"',
      );
    }
    return RollWorkerAuthResponse(
      sessionId: (json['sessionId'] as num).toInt(),
      sessionToken: token,
      rollWorkerOperatorId: (json['rollWorkerOperatorId'] as num).toInt(),
      rollWorkerName: json['rollWorkerName'] as String,
      thermoformingShiftId: (json['thermoformingShiftId'] as num).toInt(),
      thermoformingShiftLineId: (json['thermoformingShiftLineId'] as num)
          .toInt(),
      thermoformingLineId: (json['thermoformingLineId'] as num).toInt(),
      palletizingLineId: (json['palletizingLineId'] as num).toInt(),
      startedAt: DateTime.parse(startedAtRaw),
      startedAtDisplay: json['startedAtDisplay'] as String?,
    );
  }

  final int sessionId;
  final String sessionToken;
  final int rollWorkerOperatorId;
  final String rollWorkerName;
  final int thermoformingShiftId;
  final int thermoformingShiftLineId;
  final int thermoformingLineId;
  final int palletizingLineId;
  final DateTime startedAt;
  final String? startedAtDisplay;

  /// `toString` redacts [sessionToken] so it never leaks into crash reports
  /// or logs even if a developer accidentally logs the DTO.
  @override
  String toString() =>
      'RollWorkerAuthResponse(sessionId: $sessionId, '
      'sessionToken: <redacted>, rollWorkerName: $rollWorkerName, '
      'thermoformingShiftLineId: $thermoformingShiftLineId)';
}
