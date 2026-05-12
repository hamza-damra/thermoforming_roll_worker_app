import 'package:flutter/foundation.dart';

import '../../domain/entities/active_shift_line_option.dart';

/// DTO for one row of the response of
/// `GET /api/v1/thermoforming-roll-app/shift-lines/active-options`.
///
/// All fields are server-derived and read-only. The DTO never carries a
/// token, hash, pin, sessionToken or operatorAuthToken — see §4.4 of the
/// active-options update doc.
@immutable
class ActiveShiftLineOptionResponse {
  const ActiveShiftLineOptionResponse({
    required this.shiftLineId,
    required this.thermoformingShiftId,
    required this.thermoformingLineId,
    required this.thermoformingLineCode,
    required this.thermoformingLineName,
    required this.palletizingLineId,
    required this.palletizingLineCode,
    required this.palletizingLineName,
    required this.currentProductTypeId,
    required this.currentProductTypeName,
    required this.currentRollId,
    required this.currentRollGeneratedRollId,
    required this.currentRollTypeCode,
    required this.currentRollTypeName,
    required this.currentRollLastKnownWeightKg,
    required this.operatorId,
    required this.operatorName,
    required this.shiftLineStatus,
    required this.selectable,
    required this.blockingReason,
    this.existingSessionOperatorId,
    this.existingSessionOperatorName,
  });

  factory ActiveShiftLineOptionResponse.fromJson(Map<String, dynamic> json) {
    final Object? rawWeight = json['currentRollLastKnownWeightKg'];
    final double? weightKg;
    if (rawWeight == null) {
      weightKg = null;
    } else if (rawWeight is num) {
      weightKg = rawWeight.toDouble();
    } else if (rawWeight is String) {
      weightKg = double.tryParse(rawWeight);
    } else {
      weightKg = null;
    }

    final Object? rawCurrentRollId = json['currentRollId'];
    final Object? rawProductTypeId = json['currentProductTypeId'];
    final Object? rawOperatorId = json['operatorId'];
    final Object? rawExistingOperatorId = json['existingSessionOperatorId'];

    return ActiveShiftLineOptionResponse(
      shiftLineId: (json['shiftLineId'] as num).toInt(),
      thermoformingShiftId: (json['thermoformingShiftId'] as num).toInt(),
      thermoformingLineId: (json['thermoformingLineId'] as num).toInt(),
      thermoformingLineCode: json['thermoformingLineCode'] as String,
      thermoformingLineName: json['thermoformingLineName'] as String,
      palletizingLineId: (json['palletizingLineId'] as num).toInt(),
      palletizingLineCode: json['palletizingLineCode'] as String,
      palletizingLineName: json['palletizingLineName'] as String,
      currentProductTypeId: rawProductTypeId is num
          ? rawProductTypeId.toInt()
          : null,
      currentProductTypeName: json['currentProductTypeName'] as String?,
      currentRollId: rawCurrentRollId is num ? rawCurrentRollId.toInt() : null,
      currentRollGeneratedRollId: json['currentRollGeneratedRollId'] as String?,
      currentRollTypeCode: json['currentRollTypeCode'] as String?,
      currentRollTypeName: json['currentRollTypeName'] as String?,
      currentRollLastKnownWeightKg: weightKg,
      operatorId: rawOperatorId is num ? rawOperatorId.toInt() : null,
      operatorName: json['operatorName'] as String?,
      shiftLineStatus: json['shiftLineStatus'] as String,
      selectable: json['selectable'] as bool? ?? true,
      blockingReason: json['blockingReason'] as String?,
      existingSessionOperatorId: rawExistingOperatorId is num
          ? rawExistingOperatorId.toInt()
          : null,
      existingSessionOperatorName:
          json['existingSessionOperatorName'] as String?,
    );
  }

  final int shiftLineId;
  final int thermoformingShiftId;
  final int thermoformingLineId;
  final String thermoformingLineCode;
  final String thermoformingLineName;
  final int palletizingLineId;
  final String palletizingLineCode;
  final String palletizingLineName;
  final int? currentProductTypeId;
  final String? currentProductTypeName;
  final int? currentRollId;
  final String? currentRollGeneratedRollId;
  final String? currentRollTypeCode;
  final String? currentRollTypeName;

  /// Wire format is a decimal string (e.g. `"180.500"`) or null. Parsed to
  /// double on read; the backend never substitutes start-weight as fallback.
  final double? currentRollLastKnownWeightKg;
  final int? operatorId;
  final String? operatorName;
  final String shiftLineStatus;
  final bool selectable;
  final String? blockingReason;

  /// Roll worker currently holding an ACTIVE session on this shift-line, or
  /// null if no roll worker is logged in. Advisory only.
  final int? existingSessionOperatorId;
  final String? existingSessionOperatorName;

  ActiveShiftLineOption toEntity() => ActiveShiftLineOption(
    shiftLineId: shiftLineId,
    thermoformingShiftId: thermoformingShiftId,
    thermoformingLineId: thermoformingLineId,
    thermoformingLineCode: thermoformingLineCode,
    thermoformingLineName: thermoformingLineName,
    palletizingLineId: palletizingLineId,
    palletizingLineCode: palletizingLineCode,
    palletizingLineName: palletizingLineName,
    currentProductTypeId: currentProductTypeId,
    currentProductTypeName: currentProductTypeName,
    currentRollId: currentRollId,
    currentRollGeneratedRollId: currentRollGeneratedRollId,
    currentRollTypeCode: currentRollTypeCode,
    currentRollTypeName: currentRollTypeName,
    currentRollLastKnownWeightKg: currentRollLastKnownWeightKg,
    operatorId: operatorId,
    operatorName: operatorName,
    shiftLineStatus: shiftLineStatus,
    selectable: selectable,
    blockingReason: blockingReason,
    existingSessionOperatorId: existingSessionOperatorId,
    existingSessionOperatorName: existingSessionOperatorName,
  );
}
