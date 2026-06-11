import 'package:flutter/foundation.dart';

/// Success `data` for `POST .../previous-roll/keep-mounted-handover`.
///
/// - [consumedWeightKg] = what THIS (current) worker consumed =
///   `lastKnownWeight − remainingWeightKg`.
/// - [currentWeightKg] = the new mounted-roll weight the next worker continues
///   from.
/// - This call ENDS the current worker's session; the roll stays mounted
///   ([rollRemainsMounted] is `true`).
@immutable
class RollWorkerHandoverResponse {
  const RollWorkerHandoverResponse({
    required this.rollId,
    required this.generatedRollId,
    required this.finalState,
    required this.rollRemainsMounted,
    this.consumedWeightKg,
    this.currentWeightKg,
  });

  factory RollWorkerHandoverResponse.fromJson(Map<String, dynamic> json) {
    return RollWorkerHandoverResponse(
      rollId: (json['rollId'] as num).toInt(),
      generatedRollId: json['generatedRollId'] as String,
      finalState: json['finalState'] as String? ?? '',
      rollRemainsMounted: (json['rollRemainsMounted'] as bool?) ?? true,
      consumedWeightKg: (json['consumedWeightKg'] as num?)?.toDouble(),
      currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble(),
    );
  }

  final int rollId;
  final String generatedRollId;
  final String finalState;
  final bool rollRemainsMounted;
  final double? consumedWeightKg;
  final double? currentWeightKg;
}
