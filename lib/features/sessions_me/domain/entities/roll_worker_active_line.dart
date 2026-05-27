import 'package:flutter/foundation.dart';

import '../../../../core/theme/app_colors.dart';
import 'package:flutter/material.dart' show Color;

/// One ACTIVE roll-worker session as returned by `/sessions/me`.
///
/// Authoritative for: mounted roll, current product, blocked / handover /
/// takeover, line lifecycle. Rich palletizing-side data (pallets, weight
/// totals) is NOT here — that still comes from `/shift-lines/{id}/summary`.
@immutable
class RollWorkerActiveLine {
  const RollWorkerActiveLine({
    required this.sessionId,
    required this.shiftLineId,
    required this.palletizingLineId,
    required this.palletizingLineCode,
    required this.palletizingLineName,
    required this.thermoformingLineId,
    required this.thermoformingLineCode,
    required this.thermoformingLineName,
    required this.thermoformingShiftId,
    required this.supervisingOperatorId,
    required this.supervisingOperatorName,
    required this.currentPlanItemProductTypeId,
    required this.currentPlanItemProductName,
    required this.currentRollId,
    required this.currentRollGeneratedRollId,
    required this.currentRollTypeCode,
    required this.currentRollTypeName,
    required this.currentRollLastKnownWeightKg,
    required this.handoverPending,
    required this.takeoverRequestStatus,
    required this.takeoverIncomingOperatorName,
    required this.blocked,
    required this.blockedReason,
    required this.lineLifecycleStatus,
    required this.sessionStartedAt,
    required this.sessionStartedAtDisplay,
  });

  final int sessionId;
  final int shiftLineId;
  final int? palletizingLineId;
  final String? palletizingLineCode;
  final String? palletizingLineName;
  final int? thermoformingLineId;
  final String? thermoformingLineCode;
  final String? thermoformingLineName;
  final int? thermoformingShiftId;
  final int? supervisingOperatorId;
  final String? supervisingOperatorName;
  final int? currentPlanItemProductTypeId;
  final String? currentPlanItemProductName;
  final int? currentRollId;
  final String? currentRollGeneratedRollId;
  final String? currentRollTypeCode;
  final String? currentRollTypeName;
  final double? currentRollLastKnownWeightKg;
  final bool handoverPending;
  final String? takeoverRequestStatus;
  final String? takeoverIncomingOperatorName;
  final bool blocked;
  final String? blockedReason;

  /// `ACTIVE | PENDING_HANDOVER | TAKEOVER_<status>`. When [blocked] is true
  /// this mirrors [blockedReason].
  final String lineLifecycleStatus;
  final DateTime? sessionStartedAt;
  final String? sessionStartedAtDisplay;

  bool get hasMountedRoll => currentRollId != null;

  /// Deterministic accent color for this line — same line gets the same
  /// color across app launches. See [AppColors.accentForLine].
  Color get accentColor => AppColors.accentForLine(
    palletizingLineId: palletizingLineId,
    thermoformingLineId: thermoformingLineId,
    palletizingLineCode: palletizingLineCode,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RollWorkerActiveLine &&
        other.sessionId == sessionId &&
        other.shiftLineId == shiftLineId &&
        other.palletizingLineId == palletizingLineId &&
        other.palletizingLineCode == palletizingLineCode &&
        other.palletizingLineName == palletizingLineName &&
        other.thermoformingLineId == thermoformingLineId &&
        other.thermoformingLineCode == thermoformingLineCode &&
        other.thermoformingLineName == thermoformingLineName &&
        other.thermoformingShiftId == thermoformingShiftId &&
        other.supervisingOperatorId == supervisingOperatorId &&
        other.supervisingOperatorName == supervisingOperatorName &&
        other.currentPlanItemProductTypeId == currentPlanItemProductTypeId &&
        other.currentPlanItemProductName == currentPlanItemProductName &&
        other.currentRollId == currentRollId &&
        other.currentRollGeneratedRollId == currentRollGeneratedRollId &&
        other.currentRollTypeCode == currentRollTypeCode &&
        other.currentRollTypeName == currentRollTypeName &&
        other.currentRollLastKnownWeightKg == currentRollLastKnownWeightKg &&
        other.handoverPending == handoverPending &&
        other.takeoverRequestStatus == takeoverRequestStatus &&
        other.takeoverIncomingOperatorName == takeoverIncomingOperatorName &&
        other.blocked == blocked &&
        other.blockedReason == blockedReason &&
        other.lineLifecycleStatus == lineLifecycleStatus &&
        other.sessionStartedAt == sessionStartedAt &&
        other.sessionStartedAtDisplay == sessionStartedAtDisplay;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    sessionId,
    shiftLineId,
    palletizingLineId,
    palletizingLineCode,
    palletizingLineName,
    thermoformingLineId,
    thermoformingLineCode,
    thermoformingLineName,
    thermoformingShiftId,
    supervisingOperatorId,
    supervisingOperatorName,
    currentPlanItemProductTypeId,
    currentPlanItemProductName,
    currentRollId,
    currentRollGeneratedRollId,
    currentRollTypeCode,
    currentRollTypeName,
    currentRollLastKnownWeightKg,
    handoverPending,
    takeoverRequestStatus,
    takeoverIncomingOperatorName,
    blocked,
    blockedReason,
    lineLifecycleStatus,
    sessionStartedAt,
    sessionStartedAtDisplay,
  ]);
}
