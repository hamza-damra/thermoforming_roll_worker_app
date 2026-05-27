import 'package:flutter/foundation.dart';

import '../../domain/entities/roll_worker_active_line.dart';

/// DTO for one entry in the `lines` array of
/// `GET /api/v1/thermoforming-roll-app/sessions/me`.
///
/// Mirrors `RollWorkerActiveLineResponse` from the realtime + line-management
/// handoff §2.4. All `currentRoll*` fields are `null` when no roll is
/// mounted. When [blocked] is true, [blockedReason] is one of
/// `PENDING_HANDOVER` / `TAKEOVER_<status>` and [lineLifecycleStatus]
/// mirrors that.
@immutable
class RollWorkerActiveLineResponse {
  const RollWorkerActiveLineResponse({
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

  factory RollWorkerActiveLineResponse.fromJson(Map<String, dynamic> json) {
    return RollWorkerActiveLineResponse(
      sessionId: _asInt(json['sessionId']) ?? 0,
      shiftLineId: _asInt(json['shiftLineId']) ?? 0,
      palletizingLineId: _asInt(json['palletizingLineId']),
      palletizingLineCode: _asString(json['palletizingLineCode']),
      palletizingLineName: _asString(json['palletizingLineName']),
      thermoformingLineId: _asInt(json['thermoformingLineId']),
      thermoformingLineCode: _asString(json['thermoformingLineCode']),
      thermoformingLineName: _asString(json['thermoformingLineName']),
      thermoformingShiftId: _asInt(json['thermoformingShiftId']),
      supervisingOperatorId: _asInt(json['supervisingOperatorId']),
      supervisingOperatorName: _asString(json['supervisingOperatorName']),
      currentPlanItemProductTypeId: _asInt(json['currentPlanItemProductTypeId']),
      currentPlanItemProductName: _asString(json['currentPlanItemProductName']),
      currentRollId: _asInt(json['currentRollId']),
      currentRollGeneratedRollId: _asString(json['currentRollGeneratedRollId']),
      currentRollTypeCode: _asString(json['currentRollTypeCode']),
      currentRollTypeName: _asString(json['currentRollTypeName']),
      currentRollLastKnownWeightKg: _asDouble(
        json['currentRollLastKnownWeightKg'],
      ),
      handoverPending: _asBool(json['handoverPending']) ?? false,
      takeoverRequestStatus: _asString(json['takeoverRequestStatus']),
      takeoverIncomingOperatorName: _asString(
        json['takeoverIncomingOperatorName'],
      ),
      blocked: _asBool(json['blocked']) ?? false,
      blockedReason: _asString(json['blockedReason']),
      lineLifecycleStatus:
          _asString(json['lineLifecycleStatus']) ?? 'ACTIVE',
      sessionStartedAt: _asDateTime(json['sessionStartedAt']),
      sessionStartedAtDisplay: _asString(json['sessionStartedAtDisplay']),
    );
  }

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
  final String lineLifecycleStatus;
  final DateTime? sessionStartedAt;
  final String? sessionStartedAtDisplay;

  RollWorkerActiveLine toEntity() => RollWorkerActiveLine(
    sessionId: sessionId,
    shiftLineId: shiftLineId,
    palletizingLineId: palletizingLineId,
    palletizingLineCode: palletizingLineCode,
    palletizingLineName: palletizingLineName,
    thermoformingLineId: thermoformingLineId,
    thermoformingLineCode: thermoformingLineCode,
    thermoformingLineName: thermoformingLineName,
    thermoformingShiftId: thermoformingShiftId,
    supervisingOperatorId: supervisingOperatorId,
    supervisingOperatorName: supervisingOperatorName,
    currentPlanItemProductTypeId: currentPlanItemProductTypeId,
    currentPlanItemProductName: currentPlanItemProductName,
    currentRollId: currentRollId,
    currentRollGeneratedRollId: currentRollGeneratedRollId,
    currentRollTypeCode: currentRollTypeCode,
    currentRollTypeName: currentRollTypeName,
    currentRollLastKnownWeightKg: currentRollLastKnownWeightKg,
    handoverPending: handoverPending,
    takeoverRequestStatus: takeoverRequestStatus,
    takeoverIncomingOperatorName: takeoverIncomingOperatorName,
    blocked: blocked,
    blockedReason: blockedReason,
    lineLifecycleStatus: lineLifecycleStatus,
    sessionStartedAt: sessionStartedAt,
    sessionStartedAtDisplay: sessionStartedAtDisplay,
  );

  static int? _asInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

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
