import 'package:flutter/foundation.dart';

import '../../domain/entities/roll_worker_takeover.dart';

/// Request body for `POST /sessions/takeover-with-roll-declaration`.
///
/// `currentWeightKg` is REQUIRED for [RollWorkerTakeoverAction.rollRemainsMounted]
/// and omitted entirely for [RollWorkerTakeoverAction.fullConsumptionAndClose].
/// `clientRequestId` is the idempotency key — generate once per attempt and
/// reuse it on retry.
@immutable
class RollWorkerTakeoverRequest {
  const RollWorkerTakeoverRequest({
    required this.shiftLineId,
    required this.incomingOperatorPin,
    required this.action,
    required this.clientRequestId,
    this.currentWeightKg,
  });

  final int shiftLineId;
  final String incomingOperatorPin;
  final RollWorkerTakeoverAction action;
  final String clientRequestId;
  final double? currentWeightKg;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{
      'shiftLineId': shiftLineId,
      'incomingOperatorPin': incomingOperatorPin,
      'action': action.wireValue,
      'clientRequestId': clientRequestId,
    };
    // Only send the weight for the remains-mounted action; the full-consume
    // action must not carry a weight (the previous worker is credited the
    // whole last-known weight server-side).
    if (action == RollWorkerTakeoverAction.rollRemainsMounted) {
      json['currentWeightKg'] = currentWeightKg;
    }
    return json;
  }
}
