import 'package:flutter/foundation.dart';

import '../../domain/entities/previous_roll_resolution.dart';

/// DTO for the unified response of all three close endpoints:
///   - `POST .../previous-roll/full-consume`
///   - `POST .../previous-roll/return`
///   - `POST .../previous-roll/grinding`
///
/// Field shape per requirements §10.
@immutable
class PreviousRollResolutionResponse {
  const PreviousRollResolutionResponse({
    required this.rollId,
    required this.generatedRollId,
    required this.finalState,
    required this.consumedWeightKg,
    required this.remainingWeightKg,
    required this.remainderAction,
    required this.eventType,
    required this.reprintAvailable,
  });

  factory PreviousRollResolutionResponse.fromJson(Map<String, dynamic> json) {
    final PreviousRollFinalState? finalState = PreviousRollFinalState.fromWire(
      json['finalState'] as String?,
    );
    if (finalState == null) {
      throw FormatException(
        'previous-roll: unknown finalState "${json['finalState']}"',
      );
    }
    final PreviousRollRemainderAction? remainder =
        PreviousRollRemainderAction.fromWire(
          json['remainderAction'] as String?,
        );
    if (remainder == null) {
      throw FormatException(
        'previous-roll: unknown remainderAction "${json['remainderAction']}"',
      );
    }
    final PreviousRollEventType? eventType = PreviousRollEventType.fromWire(
      json['eventType'] as String?,
    );
    if (eventType == null) {
      throw FormatException(
        'previous-roll: unknown eventType "${json['eventType']}"',
      );
    }
    return PreviousRollResolutionResponse(
      rollId: (json['rollId'] as num).toInt(),
      generatedRollId: json['generatedRollId'] as String,
      finalState: finalState,
      consumedWeightKg: (json['consumedWeightKg'] as num).toDouble(),
      remainingWeightKg: (json['remainingWeightKg'] as num).toDouble(),
      remainderAction: remainder,
      eventType: eventType,
      reprintAvailable: json['reprintAvailable'] as bool,
    );
  }

  final int rollId;
  final String generatedRollId;
  final PreviousRollFinalState finalState;
  final double consumedWeightKg;
  final double remainingWeightKg;
  final PreviousRollRemainderAction remainderAction;
  final PreviousRollEventType eventType;
  final bool reprintAvailable;

  PreviousRollResolution toEntity() => PreviousRollResolution(
    rollId: rollId,
    generatedRollId: generatedRollId,
    finalState: finalState,
    consumedWeightKg: consumedWeightKg,
    remainingWeightKg: remainingWeightKg,
    remainderAction: remainderAction,
    eventType: eventType,
    reprintAvailable: reprintAvailable,
  );
}
