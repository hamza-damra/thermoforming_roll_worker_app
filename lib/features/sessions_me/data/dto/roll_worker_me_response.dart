import '../../domain/entities/roll_worker_active_line.dart';
import '../../domain/entities/roll_worker_me.dart';
import 'roll_worker_active_line_response.dart';

/// Top-level `data` payload of
/// `GET /api/v1/thermoforming-roll-app/sessions/me`.
///
/// Shape (handoff §2.4):
/// ```
/// {
///   "rollWorkerOperatorId": 7,
///   "rollWorkerName": "...",
///   "lines": [ RollWorkerActiveLineResponse, ... ]
/// }
/// ```
class RollWorkerMeResponse {
  RollWorkerMeResponse._();

  /// [envelopeData] is the `data` object already extracted from the success
  /// envelope (via `ResponseEnvelope.extractData`). Throws [FormatException]
  /// when required fields are missing or malformed. `lines` may be an empty
  /// array — that is valid and means the worker holds zero active sessions.
  static RollWorkerMe fromEnvelopeData(Object? envelopeData) {
    if (envelopeData is! Map<String, dynamic>) {
      throw const FormatException('sessions/me: malformed data envelope');
    }
    final Object? operatorIdRaw = envelopeData['rollWorkerOperatorId'];
    final int? operatorId = operatorIdRaw is num
        ? operatorIdRaw.toInt()
        : (operatorIdRaw is String ? int.tryParse(operatorIdRaw) : null);
    if (operatorId == null) {
      throw const FormatException(
        'sessions/me: missing rollWorkerOperatorId',
      );
    }
    final Object? nameRaw = envelopeData['rollWorkerName'];
    final String name = nameRaw is String ? nameRaw : '';

    final Object? rawLines = envelopeData['lines'];
    final List<RollWorkerActiveLine> lines;
    if (rawLines is List) {
      lines = rawLines
          .whereType<Map<String, dynamic>>()
          .map(RollWorkerActiveLineResponse.fromJson)
          .map((dto) => dto.toEntity())
          .toList(growable: false);
    } else {
      // Defensive: treat missing `lines` as empty (zero sessions).
      lines = const <RollWorkerActiveLine>[];
    }

    return RollWorkerMe(
      rollWorkerOperatorId: operatorId,
      rollWorkerName: name,
      lines: lines,
    );
  }
}
