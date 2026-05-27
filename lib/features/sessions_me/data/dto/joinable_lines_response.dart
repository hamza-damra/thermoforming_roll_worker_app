import '../../../shift_line/data/dto/roll_worker_bootstrap_response.dart';

/// Parses the response of
/// `GET /api/v1/thermoforming-roll-app/sessions/me/joinable-lines`.
///
/// The backend returns the same `RollWorkerShiftLineOptionResponse` rows as
/// the bootstrap picker, minus the lines the worker already owns. The wire
/// shape may be either a bare JSON array or a `{lines: [...]}` envelope —
/// this parser accepts both so backend churn won't break the picker.
///
/// We deliberately reuse the existing [RollWorkerBootstrapLineDto] and the
/// `RollWorkerBootstrapLine` domain entity: the field set matches and reusing
/// the type lets the existing picker card render joinable rows with zero
/// adaptation work.
class JoinableLinesResponse {
  JoinableLinesResponse._();

  static List<RollWorkerBootstrapLineDto> fromEnvelopeData(
    Object? envelopeData,
  ) {
    if (envelopeData is List) {
      return _parseArray(envelopeData);
    }
    if (envelopeData is Map<String, dynamic>) {
      final Object? lines = envelopeData['lines'];
      if (lines is List) return _parseArray(lines);
    }
    throw const FormatException(
      'sessions/me/joinable-lines: expected an array or {lines: [...]} object',
    );
  }

  static List<RollWorkerBootstrapLineDto> _parseArray(List<dynamic> rows) {
    return rows
        .whereType<Map<String, dynamic>>()
        .map(RollWorkerBootstrapLineDto.fromJson)
        .toList(growable: false);
  }
}
