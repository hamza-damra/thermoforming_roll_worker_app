import 'package:flutter/foundation.dart';

/// Snapshot of a mounted roll as returned by the shift-line summary endpoint.
///
/// `lastKnownWeightKg` is `null` when no weight has been recorded yet for the
/// active consumption state — never substitute the roll's start weight.
@immutable
class SummaryMountedRoll {
  const SummaryMountedRoll({
    required this.consumptionItemId,
    required this.rollId,
    required this.generatedRollId,
    required this.rollTypeCode,
    required this.rollTypeName,
    this.lastKnownWeightKg,
  });

  final int consumptionItemId;
  final int rollId;
  final String generatedRollId;
  final String rollTypeCode;
  final String rollTypeName;
  final double? lastKnownWeightKg;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SummaryMountedRoll &&
        other.consumptionItemId == consumptionItemId &&
        other.rollId == rollId &&
        other.generatedRollId == generatedRollId &&
        other.rollTypeCode == rollTypeCode &&
        other.rollTypeName == rollTypeName &&
        other.lastKnownWeightKg == lastKnownWeightKg;
  }

  @override
  int get hashCode => Object.hash(
    consumptionItemId,
    rollId,
    generatedRollId,
    rollTypeCode,
    rollTypeName,
    lastKnownWeightKg,
  );
}

/// Aggregated shift-line summary from the backend.
///
/// All roll counts come from the backend — never computed locally.
@immutable
class ShiftLineSummary {
  const ShiftLineSummary({
    required this.shiftLineId,
    required this.thermoformingLineCode,
    required this.thermoformingLineName,
    required this.completedRollsInShift,
    required this.completedRollsByCurrentWorker,
    this.mountedRoll,
  });

  final int shiftLineId;

  /// Short factory-readable code shown in the compact header and bottom nav.
  /// e.g. `"TH-01"`.
  final String thermoformingLineCode;

  /// Human-readable line name. e.g. `"خط التشكيل 1"`.
  final String thermoformingLineName;

  /// Total rolls closed on this shift-line in the current operator shift,
  /// regardless of which worker closed them.
  final int completedRollsInShift;

  /// Subset of [completedRollsInShift] closed by the current session's worker.
  final int completedRollsByCurrentWorker;

  /// Currently mounted roll, or `null` when nothing is mounted.
  final SummaryMountedRoll? mountedRoll;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ShiftLineSummary &&
        other.shiftLineId == shiftLineId &&
        other.thermoformingLineCode == thermoformingLineCode &&
        other.thermoformingLineName == thermoformingLineName &&
        other.completedRollsInShift == completedRollsInShift &&
        other.completedRollsByCurrentWorker == completedRollsByCurrentWorker &&
        other.mountedRoll == mountedRoll;
  }

  @override
  int get hashCode => Object.hash(
    shiftLineId,
    thermoformingLineCode,
    thermoformingLineName,
    completedRollsInShift,
    completedRollsByCurrentWorker,
    mountedRoll,
  );
}
