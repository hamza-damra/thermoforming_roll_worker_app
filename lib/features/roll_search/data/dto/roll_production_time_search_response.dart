import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../domain/entities/roll_search_outcome.dart';

/// Parses `GET /shift-lines/{id}/rolls/by-production-time` `data`.
///
/// ```json
/// { "status": "FOUND" | "NOT_FOUND" | "MULTIPLE_MATCHES",
///   "searchedLocalMinute": "2026-09-30T14:05", "matchCount": 1,
///   "roll": { …match… },            // FOUND only
///   "candidates": [ { …match… } ] } // MULTIPLE_MATCHES only
/// ```
///
/// Null fields are omitted by the backend. Anything required that is missing
/// or mistyped throws [FormatException], which the repository maps to an
/// [UnknownFailure] like every other malformed envelope.
abstract final class RollProductionTimeSearchResponse {
  static RollSearchOutcome parse(Map<String, dynamic> json) {
    final RollSearchStatus status = switch (json['status']) {
      'FOUND' => RollSearchStatus.found,
      'NOT_FOUND' => RollSearchStatus.notFound,
      'MULTIPLE_MATCHES' => RollSearchStatus.multipleMatches,
      final Object? other => throw FormatException(
        'rolls/by-production-time: unknown status "$other"',
      ),
    };
    final List<RollSearchMatch> matches = switch (status) {
      RollSearchStatus.found => <RollSearchMatch>[
        _match(_map(json['roll'], 'roll')),
      ],
      RollSearchStatus.multipleMatches => _list(json['candidates'])
          .map((Object? c) => _match(_map(c, 'candidates[]')))
          .toList(growable: false),
      RollSearchStatus.notFound => const <RollSearchMatch>[],
    };
    final Object? count = json['matchCount'];
    return RollSearchOutcome(
      status: status,
      matchCount: count is num ? count.toInt() : matches.length,
      matches: matches,
      searchedLocalMinute: json['searchedLocalMinute'] as String?,
    );
  }

  static RollSearchMatch _match(Map<String, dynamic> m) {
    final Object? rollId = m['rollId'];
    final Object? generatedRollId = m['generatedRollId'];
    if (rollId is! num || generatedRollId is! String) {
      throw const FormatException(
        'rolls/by-production-time: match without rollId/generatedRollId',
      );
    }
    final bool mountable = m['mountable'] == true;
    return RollSearchMatch(
      rollId: rollId.toInt(),
      generatedRollId: generatedRollId,
      producedAt: _timestamp(m['producedAt']),
      rollTypeRollCode: m['rollTypeRollCode'] as String?,
      rollTypeDisplayName: m['rollTypeDisplayName'] as String?,
      colorName: m['colorName'] as String?,
      productionKind: m['productionKind'] as String?,
      producedWeightKg: _double(m['producedWeightKg']),
      currentWeightKg: _double(m['currentWeightKg']),
      consumptionState: (m['consumptionState'] as String?) ?? 'AVAILABLE',
      consumptionStateLabel: m['consumptionStateLabel'] as String?,
      mountable: mountable,
      mountRefusal: mountable ? null : _refusal(m['mountBlockedReason']),
    );
  }

  /// The refusal as the [BusinessFailure] the scan would have produced. A
  /// non-mountable row without a reason still gets a failure (code
  /// `unknown`) so the UI never offers the mount.
  static BusinessFailure _refusal(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return const BusinessFailure(code: ErrorCode.unknown);
    }
    final Object? details = raw['details'];
    return BusinessFailure(
      code: ErrorCode.fromWire(raw['code'] as String?),
      serverMessage: raw['message'] as String?,
      details: details is Map<String, dynamic> ? details : null,
    );
  }

  static Map<String, dynamic> _map(Object? raw, String what) {
    if (raw is Map<String, dynamic>) return raw;
    throw FormatException('rolls/by-production-time: "$what" is not an object');
  }

  static List<Object?> _list(Object? raw) =>
      raw is List<dynamic> ? raw : const <Object?>[];

  static double? _double(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _timestamp(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
