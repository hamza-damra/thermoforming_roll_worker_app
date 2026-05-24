import 'package:flutter/foundation.dart';

/// Final state of a roll after a previous-roll close operation. Mirrors the
/// `finalState` field on the unified resolution response.
enum PreviousRollFinalState {
  /// Full-consume — the roll is closed with no remainder.
  consumed('CONSUMED'),

  /// Partial close — remainder returned to the warehouse.
  partiallyReturned('PARTIALLY_RETURNED'),

  /// Partial close — remainder dispatched to the grinding station.
  sentToGrinding('SENT_TO_GRINDING');

  const PreviousRollFinalState(this.wireValue);
  final String wireValue;

  static PreviousRollFinalState? fromWire(String? code) {
    if (code == null) return null;
    for (final PreviousRollFinalState v in PreviousRollFinalState.values) {
      if (v.wireValue == code) return v;
    }
    return null;
  }
}

/// What happened to the remainder.
enum PreviousRollRemainderAction {
  none('NONE'),
  returned('RETURN'),
  grinding('GRINDING');

  const PreviousRollRemainderAction(this.wireValue);
  final String wireValue;

  static PreviousRollRemainderAction? fromWire(String? code) {
    if (code == null) return null;
    for (final PreviousRollRemainderAction v
        in PreviousRollRemainderAction.values) {
      if (v.wireValue == code) return v;
    }
    return null;
  }
}

/// Audit-style event published by the backend.
enum PreviousRollEventType {
  closedFull('CLOSED_FULL'),
  closedPartialReturn('CLOSED_PARTIAL_RETURN'),
  closedPartialGrinding('CLOSED_PARTIAL_GRINDING');

  const PreviousRollEventType(this.wireValue);
  final String wireValue;

  static PreviousRollEventType? fromWire(String? code) {
    if (code == null) return null;
    for (final PreviousRollEventType v in PreviousRollEventType.values) {
      if (v.wireValue == code) return v;
    }
    return null;
  }
}

/// Domain entity for the previous-roll close response. The same shape is
/// returned by all three endpoints (full-consume / return / grinding).
@immutable
class PreviousRollResolution {
  const PreviousRollResolution({
    required this.rollId,
    required this.generatedRollId,
    required this.finalState,
    required this.consumedWeightKg,
    required this.remainingWeightKg,
    required this.remainderAction,
    required this.eventType,
    required this.reprintAvailable,
    this.labelTimestamp,
    this.reprintLabelType,
  });

  final int rollId;
  final String generatedRollId;
  final PreviousRollFinalState finalState;

  /// Computed by the backend (`segmentStartWeight − remainingWeightKg`).
  final double consumedWeightKg;

  /// 0 for full-consume; declared remainder for return/grinding.
  final double remainingWeightKg;

  final PreviousRollRemainderAction remainderAction;
  final PreviousRollEventType eventType;

  /// `true` after partial close (return or grinding) — Stage 8 will surface
  /// the reprint button. Stage 6 only tracks the flag.
  final bool reprintAvailable;

  /// Backend-authoritative timestamp to print on the remainder label
  /// (auto-print path). Null when the backend has not yet exposed it —
  /// the auto-print path then falls through to `/reprint-label`'s
  /// `createdAt`, or aborts with a missing-field error.
  final DateTime? labelTimestamp;

  /// `RETURN_REMAINING` | `GRINDING_REMAINING` — drives the GRINDING scrap-
  /// icon switch in the renderer. Null on older backends.
  final String? reprintLabelType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PreviousRollResolution &&
        other.rollId == rollId &&
        other.generatedRollId == generatedRollId &&
        other.finalState == finalState &&
        other.consumedWeightKg == consumedWeightKg &&
        other.remainingWeightKg == remainingWeightKg &&
        other.remainderAction == remainderAction &&
        other.eventType == eventType &&
        other.reprintAvailable == reprintAvailable &&
        other.labelTimestamp == labelTimestamp &&
        other.reprintLabelType == reprintLabelType;
  }

  @override
  int get hashCode => Object.hash(
    rollId,
    generatedRollId,
    finalState,
    consumedWeightKg,
    remainingWeightKg,
    remainderAction,
    eventType,
    reprintAvailable,
    labelTimestamp,
    reprintLabelType,
  );
}
