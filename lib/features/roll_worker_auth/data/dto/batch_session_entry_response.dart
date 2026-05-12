import 'package:flutter/foundation.dart';

/// One entry from the `sessions` array of `POST /sessions/start-batch`.
///
/// Critical: this is the ONLY response that carries the raw [sessionToken]
/// for a given shift-line. Backend stores only its SHA-256 hash, so the
/// app must persist this raw value to its secure store immediately, then
/// drop it from in-memory state.
@immutable
class BatchSessionEntryResponse {
  const BatchSessionEntryResponse({
    required this.shiftLineId,
    required this.sessionId,
    required this.sessionToken,
    required this.thermoformingShiftId,
    required this.thermoformingLineId,
    required this.palletizingLineId,
    required this.startedAt,
    this.startedAtDisplay,
  });

  factory BatchSessionEntryResponse.fromJson(Map<String, dynamic> json) {
    final String? token = json['sessionToken'] as String?;
    if (token == null || token.isEmpty) {
      throw const FormatException(
        'BatchSessionEntryResponse: missing required field "sessionToken"',
      );
    }
    final String? startedAtRaw = json['startedAt'] as String?;
    if (startedAtRaw == null) {
      throw const FormatException(
        'BatchSessionEntryResponse: missing required field "startedAt"',
      );
    }
    return BatchSessionEntryResponse(
      shiftLineId: (json['shiftLineId'] as num).toInt(),
      sessionId: (json['sessionId'] as num).toInt(),
      sessionToken: token,
      thermoformingShiftId: (json['thermoformingShiftId'] as num).toInt(),
      thermoformingLineId: (json['thermoformingLineId'] as num).toInt(),
      palletizingLineId: (json['palletizingLineId'] as num).toInt(),
      startedAt: DateTime.parse(startedAtRaw),
      startedAtDisplay: json['startedAtDisplay'] as String?,
    );
  }

  final int shiftLineId;
  final int sessionId;
  final String sessionToken;
  final int thermoformingShiftId;
  final int thermoformingLineId;
  final int palletizingLineId;
  final DateTime startedAt;
  final String? startedAtDisplay;

  /// Redacts [sessionToken] so a stray log line never leaks the secret.
  @override
  String toString() =>
      'BatchSessionEntryResponse(shiftLineId: $shiftLineId, '
      'sessionId: $sessionId, sessionToken: <redacted>, '
      'thermoformingLineId: $thermoformingLineId)';
}
