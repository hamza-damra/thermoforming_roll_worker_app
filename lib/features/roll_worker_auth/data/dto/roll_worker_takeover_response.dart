import 'package:flutter/foundation.dart';

/// Success `data` for `POST /sessions/takeover-with-roll-declaration`.
///
/// On a fresh takeover [sessionToken] is the incoming worker's new raw token,
/// returned once. On a duplicate `clientRequestId` the backend returns
/// `alreadyProcessed: true` with no token — recover by re-logging in with the
/// incoming PIN (the line is now owned by this operator).
@immutable
class RollWorkerTakeoverResponse {
  const RollWorkerTakeoverResponse({
    required this.alreadyProcessed,
    required this.action,
    required this.rollClosed,
    required this.rollRemainsMounted,
    this.sessionId,
    this.sessionToken,
    this.rollWorkerOperatorId,
    this.rollWorkerName,
    this.thermoformingShiftLineId,
    this.palletizingLineId,
    this.currentWeightKg,
    this.previousWorkerName,
  });

  factory RollWorkerTakeoverResponse.fromJson(Map<String, dynamic> json) {
    return RollWorkerTakeoverResponse(
      alreadyProcessed: (json['alreadyProcessed'] as bool?) ?? false,
      action: json['action'] as String? ?? '',
      rollClosed: (json['rollClosed'] as bool?) ?? false,
      rollRemainsMounted: (json['rollRemainsMounted'] as bool?) ?? false,
      sessionId: (json['sessionId'] as num?)?.toInt(),
      sessionToken: json['sessionToken'] as String?,
      rollWorkerOperatorId: (json['rollWorkerOperatorId'] as num?)?.toInt(),
      rollWorkerName: json['rollWorkerName'] as String?,
      thermoformingShiftLineId:
          (json['thermoformingShiftLineId'] as num?)?.toInt(),
      palletizingLineId: (json['palletizingLineId'] as num?)?.toInt(),
      currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble(),
      previousWorkerName: json['previousWorkerName'] as String?,
    );
  }

  final bool alreadyProcessed;
  final String action;
  final bool rollClosed;
  final bool rollRemainsMounted;
  final int? sessionId;
  final String? sessionToken;
  final int? rollWorkerOperatorId;
  final String? rollWorkerName;
  final int? thermoformingShiftLineId;
  final int? palletizingLineId;
  final double? currentWeightKg;
  final String? previousWorkerName;
}
