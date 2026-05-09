import 'package:flutter/foundation.dart';

/// Roll's `RollConsumptionState` at the time the reprint was requested.
/// Drives the badge on the printed sticker (per requirements §12):
///   - PARTIALLY_RETURNED → "إعادة طباعة بعد الإرجاع"
///   - SENT_TO_GRINDING   → "إعادة طباعة قبل الجرش"
enum RollConsumptionState {
  available('AVAILABLE'),
  inConsumption('IN_CONSUMPTION'),
  consumed('CONSUMED'),
  partiallyReturned('PARTIALLY_RETURNED'),
  sentToGrinding('SENT_TO_GRINDING'),
  blocked('BLOCKED');

  const RollConsumptionState(this.wireValue);
  final String wireValue;

  static RollConsumptionState? fromWire(String? code) {
    if (code == null) return null;
    for (final RollConsumptionState v in RollConsumptionState.values) {
      if (v.wireValue == code) return v;
    }
    return null;
  }
}

/// All fields the backend sends back for reprinting a label. Maps directly
/// to the canonical sticker template — never enrich, never recompute,
/// never invent serials client-side.
@immutable
class RollLabel {
  const RollLabel({
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

  /// Declared remainder for warehouse / grinding station.
  final double lastKnownWeightKg;

  bool get isPartiallyReturned =>
      consumptionState == RollConsumptionState.partiallyReturned;
  bool get isSentToGrinding =>
      consumptionState == RollConsumptionState.sentToGrinding;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RollLabel &&
        other.generatedRollId == generatedRollId &&
        other.prefixSnapshot == prefixSnapshot &&
        other.serialNumber == serialNumber &&
        other.rollTypeId == rollTypeId &&
        other.rollTypeRollCode == rollTypeRollCode &&
        other.rollTypeDisplayName == rollTypeDisplayName &&
        other.colorName == colorName &&
        other.standardLengthM == standardLengthM &&
        other.standardWeightKg == standardWeightKg &&
        other.actualLengthM == actualLengthM &&
        other.actualWeightKg == actualWeightKg &&
        other.actualThicknessMm == actualThicknessMm &&
        other.productionKind == productionKind &&
        other.consumptionState == consumptionState &&
        other.lastKnownWeightKg == lastKnownWeightKg;
  }

  @override
  int get hashCode => Object.hashAll(<Object>[
    generatedRollId,
    prefixSnapshot,
    serialNumber,
    rollTypeId,
    rollTypeRollCode,
    rollTypeDisplayName,
    colorName,
    standardLengthM,
    standardWeightKg,
    actualLengthM,
    actualWeightKg,
    actualThicknessMm,
    productionKind,
    consumptionState,
    lastKnownWeightKg,
  ]);
}
