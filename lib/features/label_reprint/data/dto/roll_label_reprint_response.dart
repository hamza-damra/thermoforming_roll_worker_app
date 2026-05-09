import 'package:flutter/foundation.dart';

import '../../domain/entities/roll_label.dart';

/// DTO for `GET /rolls/{generatedRollId}/reprint-label`.
///
/// Mirrors the canonical roll sticker payload exactly. Every field is the
/// source of truth for the printer template — the client never enriches.
@immutable
class RollLabelReprintResponse {
  const RollLabelReprintResponse({
    required this.generatedRollId,
    required this.prefixSnapshot,
    required this.serialNumber,
    required this.rollTypeId,
    required this.rollTypeRollCode,
    required this.rollTypeDisplayName,
    required this.colorName,
    required this.standardLengthM,
    required this.standardWeightKg,
    required this.actualLengthM,
    required this.actualWeightKg,
    required this.actualThicknessMm,
    required this.productionKind,
    required this.consumptionState,
    required this.lastKnownWeightKg,
  });

  factory RollLabelReprintResponse.fromJson(Map<String, dynamic> json) {
    final RollConsumptionState? state = RollConsumptionState.fromWire(
      json['consumptionState'] as String?,
    );
    if (state == null) {
      throw FormatException(
        'reprint-label: unknown consumptionState '
        '"${json['consumptionState']}"',
      );
    }
    return RollLabelReprintResponse(
      generatedRollId: json['generatedRollId'] as String,
      prefixSnapshot: json['prefixSnapshot'] as String,
      serialNumber: (json['serialNumber'] as num).toInt(),
      rollTypeId: (json['rollTypeId'] as num).toInt(),
      rollTypeRollCode: json['rollTypeRollCode'] as String,
      rollTypeDisplayName: json['rollTypeDisplayName'] as String,
      colorName: json['colorName'] as String,
      standardLengthM: (json['standardLengthM'] as num).toDouble(),
      standardWeightKg: (json['standardWeightKg'] as num).toDouble(),
      actualLengthM: (json['actualLengthM'] as num).toDouble(),
      actualWeightKg: (json['actualWeightKg'] as num).toDouble(),
      actualThicknessMm: (json['actualThicknessMm'] as num).toDouble(),
      productionKind: json['productionKind'] as String,
      consumptionState: state,
      lastKnownWeightKg: (json['lastKnownWeightKg'] as num).toDouble(),
    );
  }

  final String generatedRollId;
  final String prefixSnapshot;
  final int serialNumber;
  final int rollTypeId;
  final String rollTypeRollCode;
  final String rollTypeDisplayName;
  final String colorName;
  final double standardLengthM;
  final double standardWeightKg;
  final double actualLengthM;
  final double actualWeightKg;
  final double actualThicknessMm;
  final String productionKind;
  final RollConsumptionState consumptionState;
  final double lastKnownWeightKg;

  RollLabel toEntity() => RollLabel(
    generatedRollId: generatedRollId,
    prefixSnapshot: prefixSnapshot,
    serialNumber: serialNumber,
    rollTypeId: rollTypeId,
    rollTypeRollCode: rollTypeRollCode,
    rollTypeDisplayName: rollTypeDisplayName,
    colorName: colorName,
    standardLengthM: standardLengthM,
    standardWeightKg: standardWeightKg,
    actualLengthM: actualLengthM,
    actualWeightKg: actualWeightKg,
    actualThicknessMm: actualThicknessMm,
    productionKind: productionKind,
    consumptionState: consumptionState,
    lastKnownWeightKg: lastKnownWeightKg,
  );
}
