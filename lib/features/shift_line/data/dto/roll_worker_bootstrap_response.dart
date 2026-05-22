import 'package:flutter/foundation.dart';

import '../../domain/entities/roll_worker_bootstrap_line.dart';

/// DTO for one row of the response of
/// `GET /api/v1/thermoforming-roll-app/bootstrap`.
///
/// Every nullable / state field is `@JsonInclude(NON_NULL)` on the backend,
/// so the parser tolerates absent keys. All fields are server-derived and
/// read-only — the DTO never carries a token, hash, pin or sessionToken.
@immutable
class RollWorkerBootstrapLineDto {
  const RollWorkerBootstrapLineDto({
    required this.thermoformingLineId,
    required this.lineCode,
    required this.lineName,
    required this.machineNumber,
    required this.palletizingLineId,
    required this.productionLineId,
    required this.palletizingLineCode,
    required this.palletizingLineName,
    required this.shiftLineId,
    required this.thermoformingShiftId,
    required this.currentProductTypeId,
    required this.currentProductTypeName,
    required this.activeOperatorId,
    required this.activeOperatorName,
    required this.currentRollId,
    required this.currentRollGeneratedRollId,
    required this.currentRollTypeCode,
    required this.currentRollTypeName,
    required this.currentRollLastKnownWeightKg,
    required this.selectable,
    required this.canStartRollWorkerSession,
    required this.blocked,
    required this.blockedReason,
    required this.handoverPending,
    required this.takeoverRequestStatus,
    required this.takeoverIncomingOperatorName,
    required this.lineLifecycleStatus,
    required this.updatedAt,
  });

  factory RollWorkerBootstrapLineDto.fromJson(Map<String, dynamic> json) {
    final bool selectable = _asBool(json['selectable']) ?? false;
    return RollWorkerBootstrapLineDto(
      thermoformingLineId: _asInt(json['thermoformingLineId']) ?? 0,
      lineCode: _asString(json['lineCode']) ?? '',
      lineName: _asString(json['lineName']) ?? '',
      machineNumber: _asInt(json['machineNumber']),
      palletizingLineId: _asInt(json['palletizingLineId']),
      productionLineId:
          _asInt(json['productionLineId']) ?? _asInt(json['palletizingLineId']),
      palletizingLineCode: _asString(json['palletizingLineCode']),
      palletizingLineName: _asString(json['palletizingLineName']),
      shiftLineId: _asInt(json['shiftLineId']),
      thermoformingShiftId: _asInt(json['thermoformingShiftId']),
      currentProductTypeId: _asInt(json['currentProductTypeId']),
      currentProductTypeName: _asString(json['currentProductTypeName']),
      activeOperatorId: _asInt(json['activeOperatorId']),
      activeOperatorName: _asString(json['activeOperatorName']),
      currentRollId: _asInt(json['currentRollId']),
      currentRollGeneratedRollId: _asString(json['currentRollGeneratedRollId']),
      currentRollTypeCode: _asString(json['currentRollTypeCode']),
      currentRollTypeName: _asString(json['currentRollTypeName']),
      currentRollLastKnownWeightKg: _asDouble(
        json['currentRollLastKnownWeightKg'],
      ),
      selectable: selectable,
      // `canStartRollWorkerSession` is documented as == `selectable`; fall
      // back to it when the backend omits the explicit flag.
      canStartRollWorkerSession:
          _asBool(json['canStartRollWorkerSession']) ?? selectable,
      blocked: _asBool(json['blocked']) ?? false,
      blockedReason: _asString(json['blockedReason']),
      handoverPending: _asBool(json['handoverPending']) ?? false,
      takeoverRequestStatus: _asString(json['takeoverRequestStatus']),
      takeoverIncomingOperatorName: _asString(
        json['takeoverIncomingOperatorName'],
      ),
      lineLifecycleStatus:
          _asString(json['lineLifecycleStatus']) ?? 'NO_ACTIVE_SHIFT',
      updatedAt: _asDateTime(json['updatedAt']),
    );
  }

  final int thermoformingLineId;
  final String lineCode;
  final String lineName;
  final int? machineNumber;
  final int? palletizingLineId;
  final int? productionLineId;
  final String? palletizingLineCode;
  final String? palletizingLineName;
  final int? shiftLineId;
  final int? thermoformingShiftId;
  final int? currentProductTypeId;
  final String? currentProductTypeName;
  final int? activeOperatorId;
  final String? activeOperatorName;
  final int? currentRollId;
  final String? currentRollGeneratedRollId;
  final String? currentRollTypeCode;
  final String? currentRollTypeName;

  /// Wire format is a JSON number OR a decimal string (e.g. `"180.500"`) or
  /// null. Parsed to double on read.
  final double? currentRollLastKnownWeightKg;
  final bool selectable;
  final bool canStartRollWorkerSession;
  final bool blocked;
  final String? blockedReason;
  final bool handoverPending;
  final String? takeoverRequestStatus;
  final String? takeoverIncomingOperatorName;
  final String lineLifecycleStatus;
  final DateTime? updatedAt;

  RollWorkerBootstrapLine toEntity() => RollWorkerBootstrapLine(
    thermoformingLineId: thermoformingLineId,
    lineCode: lineCode,
    lineName: lineName,
    machineNumber: machineNumber,
    palletizingLineId: palletizingLineId,
    productionLineId: productionLineId,
    palletizingLineCode: palletizingLineCode,
    palletizingLineName: palletizingLineName,
    shiftLineId: shiftLineId,
    thermoformingShiftId: thermoformingShiftId,
    currentProductTypeId: currentProductTypeId,
    currentProductTypeName: currentProductTypeName,
    activeOperatorId: activeOperatorId,
    activeOperatorName: activeOperatorName,
    currentRollId: currentRollId,
    currentRollGeneratedRollId: currentRollGeneratedRollId,
    currentRollTypeCode: currentRollTypeCode,
    currentRollTypeName: currentRollTypeName,
    currentRollLastKnownWeightKg: currentRollLastKnownWeightKg,
    selectable: selectable,
    canStartRollWorkerSession: canStartRollWorkerSession,
    blocked: blocked,
    blockedReason: blockedReason,
    handoverPending: handoverPending,
    takeoverRequestStatus: takeoverRequestStatus,
    takeoverIncomingOperatorName: takeoverIncomingOperatorName,
    lineLifecycleStatus: lineLifecycleStatus,
    updatedAt: updatedAt,
  );

  static int? _asInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Accepts a JSON number or a decimal string — the backend may send either
  /// for `currentRollLastKnownWeightKg`.
  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String? _asString(Object? v) {
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  static bool? _asBool(Object? v) {
    if (v is bool) return v;
    if (v is String) {
      if (v.toLowerCase() == 'true') return true;
      if (v.toLowerCase() == 'false') return false;
    }
    return null;
  }

  static DateTime? _asDateTime(Object? v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// Unwraps the `{ success, data: { lines: [...] }, error }` envelope of the
/// bootstrap response into a list of [RollWorkerBootstrapLineDto].
class RollWorkerBootstrapResponse {
  RollWorkerBootstrapResponse._();

  /// [envelopeData] is the `data` object already extracted from the success
  /// envelope (via `ResponseEnvelope.extractData`). Throws [FormatException]
  /// when the `lines` array is missing or malformed.
  static List<RollWorkerBootstrapLineDto> linesFromEnvelopeData(
    Object? envelopeData,
  ) {
    if (envelopeData is! Map<String, dynamic>) {
      throw const FormatException('bootstrap: malformed data envelope');
    }
    final Object? lines = envelopeData['lines'];
    if (lines is! List) {
      throw const FormatException('bootstrap: `lines` is not an array');
    }
    return lines
        .whereType<Map<String, dynamic>>()
        .map(RollWorkerBootstrapLineDto.fromJson)
        .toList(growable: false);
  }
}
