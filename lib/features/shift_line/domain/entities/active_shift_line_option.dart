import 'package:flutter/foundation.dart';

/// Domain entity for one row returned by
/// `GET /api/v1/thermoforming-roll-app/shift-lines/active-options`.
///
/// Represents a Thermoforming shift-line that the operator app has already
/// opened against the current shift, presented as a selectable picker entry
/// in the Roll Worker app.
@immutable
class ActiveShiftLineOption {
  const ActiveShiftLineOption({
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

  /// Internal id of the Thermoforming shift-line allocation. The Roll
  /// Worker app uses this as `{shiftLineId}` for every other call.
  final int shiftLineId;

  final int thermoformingShiftId;
  final int thermoformingLineId;
  final String thermoformingLineCode;
  final String thermoformingLineName;

  final int palletizingLineId;
  final String palletizingLineCode;
  final String palletizingLineName;

  /// Current product on the line; null when no product has been chosen yet.
  final int? currentProductTypeId;
  final String? currentProductTypeName;

  /// Mounted-roll details, all null when no roll is mounted.
  final int? currentRollId;
  final String? currentRollGeneratedRollId;
  final String? currentRollTypeCode;
  final String? currentRollTypeName;
  final double? currentRollLastKnownWeightKg;

  /// Operator who opened the line (display only).
  final int? operatorId;
  final String? operatorName;

  /// Backend-side line status (e.g. `ACTIVE`).
  final String shiftLineStatus;

  /// Future-proof gating flag. The first-pass backend always returns `true`;
  /// the UI must still respect `false` if it ever appears, rendering the row
  /// disabled and showing [blockingReason].
  final bool selectable;
  final String? blockingReason;

  /// Roll worker currently holding an ACTIVE session on this shift-line, or
  /// `null` if no roll worker is logged in. Advisory only — `selectable`
  /// stays `true` even when populated. The backend resolves conflicts at
  /// batch-start time (idempotent reuse if same worker, hard reject if not).
  final int? existingSessionOperatorId;
  final String? existingSessionOperatorName;

  bool get hasMountedRoll => currentRollId != null;

  bool get hasOtherActiveOperator => existingSessionOperatorId != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActiveShiftLineOption &&
        other.shiftLineId == shiftLineId &&
        other.thermoformingShiftId == thermoformingShiftId &&
        other.thermoformingLineId == thermoformingLineId &&
        other.thermoformingLineCode == thermoformingLineCode &&
        other.thermoformingLineName == thermoformingLineName &&
        other.palletizingLineId == palletizingLineId &&
        other.palletizingLineCode == palletizingLineCode &&
        other.palletizingLineName == palletizingLineName &&
        other.currentProductTypeId == currentProductTypeId &&
        other.currentProductTypeName == currentProductTypeName &&
        other.currentRollId == currentRollId &&
        other.currentRollGeneratedRollId == currentRollGeneratedRollId &&
        other.currentRollTypeCode == currentRollTypeCode &&
        other.currentRollTypeName == currentRollTypeName &&
        other.currentRollLastKnownWeightKg == currentRollLastKnownWeightKg &&
        other.operatorId == operatorId &&
        other.operatorName == operatorName &&
        other.shiftLineStatus == shiftLineStatus &&
        other.selectable == selectable &&
        other.blockingReason == blockingReason &&
        other.existingSessionOperatorId == existingSessionOperatorId &&
        other.existingSessionOperatorName == existingSessionOperatorName;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    shiftLineId,
    thermoformingShiftId,
    thermoformingLineId,
    thermoformingLineCode,
    thermoformingLineName,
    palletizingLineId,
    palletizingLineCode,
    palletizingLineName,
    currentProductTypeId,
    currentProductTypeName,
    currentRollId,
    currentRollGeneratedRollId,
    currentRollTypeCode,
    currentRollTypeName,
    currentRollLastKnownWeightKg,
    operatorId,
    operatorName,
    shiftLineStatus,
    selectable,
    blockingReason,
    existingSessionOperatorId,
    existingSessionOperatorName,
  ]);
}
