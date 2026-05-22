import 'package:flutter/foundation.dart';

/// Domain entity for one row returned by
/// `GET /api/v1/thermoforming-roll-app/bootstrap`.
///
/// Represents one **active thermoforming machine** (`ThermoformingLine`),
/// whether or not an operator is currently active on it. Rows are keyed by
/// the stable, non-nullable [thermoformingLineId] — they never appear or
/// disappear as operators come and go; they only change state.
///
/// [shiftLineId] is `null` until an operator activates the machine. The Roll
/// Worker app uses it as `{shiftLineId}` for in-session calls, but only when
/// [selectable] is `true` (a selectable row always has a non-null
/// [shiftLineId]).
@immutable
class RollWorkerBootstrapLine {
  const RollWorkerBootstrapLine({
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

  /// Stable machine-keyed row id. Picker rows are keyed by this — never by
  /// [shiftLineId], which is `null` until an operator activates the machine.
  final int thermoformingLineId;

  final String lineCode;
  final String lineName;
  final int? machineNumber;

  final int? palletizingLineId;

  /// Alias of [palletizingLineId] — kept distinct in case the backend ever
  /// diverges them.
  final int? productionLineId;
  final String? palletizingLineCode;
  final String? palletizingLineName;

  /// Internal id of the active thermoforming shift-line allocation, or `null`
  /// when no operator has activated this machine yet.
  final int? shiftLineId;
  final int? thermoformingShiftId;

  /// Current product on the line; `null` when no product has been chosen.
  final int? currentProductTypeId;
  final String? currentProductTypeName;

  /// Operator who activated the line (display only). `null` when idle.
  final int? activeOperatorId;
  final String? activeOperatorName;

  /// Mounted-roll details, all `null` when no roll is mounted.
  final int? currentRollId;
  final String? currentRollGeneratedRollId;
  final String? currentRollTypeCode;
  final String? currentRollTypeName;
  final double? currentRollLastKnownWeightKg;

  /// `true` iff an ACTIVE shift-line exists on this machine AND it is not
  /// blocked by a pending handover or an active takeover. Equal to
  /// [canStartRollWorkerSession]. A row is tappable in the picker iff this
  /// is `true`.
  final bool selectable;
  final bool canStartRollWorkerSession;

  /// `true` while a handover / takeover is in progress on the machine.
  final bool blocked;

  /// `PENDING_HANDOVER` | `TAKEOVER_<status>` | `null`.
  final String? blockedReason;
  final bool handoverPending;
  final String? takeoverRequestStatus;
  final String? takeoverIncomingOperatorName;

  /// `ACTIVE` | `PENDING_HANDOVER` | `TAKEOVER_*` | `NO_ACTIVE_SHIFT`.
  final String lineLifecycleStatus;
  final DateTime? updatedAt;

  bool get hasMountedRoll => currentRollId != null;

  bool get hasActiveOperator => activeOperatorId != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RollWorkerBootstrapLine &&
        other.thermoformingLineId == thermoformingLineId &&
        other.lineCode == lineCode &&
        other.lineName == lineName &&
        other.machineNumber == machineNumber &&
        other.palletizingLineId == palletizingLineId &&
        other.productionLineId == productionLineId &&
        other.palletizingLineCode == palletizingLineCode &&
        other.palletizingLineName == palletizingLineName &&
        other.shiftLineId == shiftLineId &&
        other.thermoformingShiftId == thermoformingShiftId &&
        other.currentProductTypeId == currentProductTypeId &&
        other.currentProductTypeName == currentProductTypeName &&
        other.activeOperatorId == activeOperatorId &&
        other.activeOperatorName == activeOperatorName &&
        other.currentRollId == currentRollId &&
        other.currentRollGeneratedRollId == currentRollGeneratedRollId &&
        other.currentRollTypeCode == currentRollTypeCode &&
        other.currentRollTypeName == currentRollTypeName &&
        other.currentRollLastKnownWeightKg == currentRollLastKnownWeightKg &&
        other.selectable == selectable &&
        other.canStartRollWorkerSession == canStartRollWorkerSession &&
        other.blocked == blocked &&
        other.blockedReason == blockedReason &&
        other.handoverPending == handoverPending &&
        other.takeoverRequestStatus == takeoverRequestStatus &&
        other.takeoverIncomingOperatorName == takeoverIncomingOperatorName &&
        other.lineLifecycleStatus == lineLifecycleStatus &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    thermoformingLineId,
    lineCode,
    lineName,
    machineNumber,
    palletizingLineId,
    productionLineId,
    palletizingLineCode,
    palletizingLineName,
    shiftLineId,
    thermoformingShiftId,
    currentProductTypeId,
    currentProductTypeName,
    activeOperatorId,
    activeOperatorName,
    currentRollId,
    currentRollGeneratedRollId,
    currentRollTypeCode,
    currentRollTypeName,
    currentRollLastKnownWeightKg,
    selectable,
    canStartRollWorkerSession,
    blocked,
    blockedReason,
    handoverPending,
    takeoverRequestStatus,
    takeoverIncomingOperatorName,
    lineLifecycleStatus,
    updatedAt,
  ]);
}
