import 'package:flutter/foundation.dart';

import 'batch_session_entry_response.dart';

/// Top-level DTO for `POST /api/v1/thermoforming-roll-app/sessions/start-batch`.
///
/// `rollWorkerOperatorId` and `rollWorkerName` are the same across every
/// entry — the PIN is validated exactly once per batch. The list is
/// returned in input order after de-duplication.
@immutable
class BatchSessionStartResponse {
  const BatchSessionStartResponse({
    required this.rollWorkerOperatorId,
    required this.rollWorkerName,
    required this.sessions,
  });

  factory BatchSessionStartResponse.fromJson(Map<String, dynamic> json) {
    final Object? rawSessions = json['sessions'];
    if (rawSessions is! List) {
      throw const FormatException(
        'BatchSessionStartResponse: "sessions" is not a list',
      );
    }
    final List<BatchSessionEntryResponse> entries = rawSessions
        .whereType<Map<String, dynamic>>()
        .map(BatchSessionEntryResponse.fromJson)
        .toList(growable: false);
    return BatchSessionStartResponse(
      rollWorkerOperatorId: (json['rollWorkerOperatorId'] as num).toInt(),
      rollWorkerName: json['rollWorkerName'] as String,
      sessions: entries,
    );
  }

  final int rollWorkerOperatorId;
  final String rollWorkerName;
  final List<BatchSessionEntryResponse> sessions;

  @override
  String toString() =>
      'BatchSessionStartResponse(rollWorkerOperatorId: $rollWorkerOperatorId, '
      'rollWorkerName: $rollWorkerName, sessions: $sessions)';
}
