import 'package:flutter/foundation.dart';

/// Domain entity for a roll that is currently mounted (`IN_CONSUMPTION`) on
/// the worker's Thermoforming shift-line. Built from the scan-roll response.
@immutable
class MountedRoll {
  const MountedRoll({
    required this.rollId,
    required this.generatedRollId,
    required this.rollTypeId,
    required this.rollTypeRollCode,
    required this.rollTypeDisplayName,
    required this.colorName,
    required this.productTypeId,
    required this.productTypeName,
    required this.consumptionItemId,
    required this.activeSegmentId,
    required this.state,
    required this.lastKnownWeightKg,
  });

  /// Internal numeric id of the roll.
  final int rollId;

  /// 12-digit `PPPSSSSSSSSS` (3-digit product prefix + 9-digit serial).
  /// Same value the worker scanned; appears on the QR sticker.
  final String generatedRollId;

  final int rollTypeId;
  final String rollTypeRollCode;
  final String rollTypeDisplayName;
  final String colorName;

  final int productTypeId;
  final String productTypeName;

  /// Active consumption-item id used by analytics; the app never sends this
  /// back — every mutating endpoint takes only the shift-line id.
  final int consumptionItemId;

  /// Active segment id (open segment within the consumption item).
  final int activeSegmentId;

  /// Backend state, e.g. `IN_CONSUMPTION`.
  final String state;

  /// Last known physical weight (kg). Used as the segment-start weight for
  /// previous-roll resolution bounds checks in Stage 6.
  final double lastKnownWeightKg;

  bool get isInConsumption => state == 'IN_CONSUMPTION';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MountedRoll &&
        other.rollId == rollId &&
        other.generatedRollId == generatedRollId &&
        other.rollTypeId == rollTypeId &&
        other.rollTypeRollCode == rollTypeRollCode &&
        other.rollTypeDisplayName == rollTypeDisplayName &&
        other.colorName == colorName &&
        other.productTypeId == productTypeId &&
        other.productTypeName == productTypeName &&
        other.consumptionItemId == consumptionItemId &&
        other.activeSegmentId == activeSegmentId &&
        other.state == state &&
        other.lastKnownWeightKg == lastKnownWeightKg;
  }

  @override
  int get hashCode => Object.hash(
    rollId,
    generatedRollId,
    rollTypeId,
    rollTypeRollCode,
    rollTypeDisplayName,
    colorName,
    productTypeId,
    productTypeName,
    consumptionItemId,
    activeSegmentId,
    state,
    lastKnownWeightKg,
  );
}
