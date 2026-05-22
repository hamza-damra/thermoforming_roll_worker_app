import 'package:flutter/foundation.dart';

/// Lifecycle status of a Line Takeover Request, mirrored from the backend
/// `takeoverRequestStatus` field.
///
/// The Roll Worker app is a passive observer — it only *reads* this status,
/// it never transitions it. An unrecognised wire value maps to [unknown]
/// rather than throwing, so a backend addition never crashes the UI.
enum TakeoverStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  rejected('REJECTED'),
  timeoutAutoReleased('TIMEOUT_AUTO_RELEASED'),
  postAcceptTimeoutAutoReleased('POST_ACCEPT_TIMEOUT_AUTO_RELEASED'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  unknown('UNKNOWN');

  const TakeoverStatus(this.wireValue);

  final String wireValue;

  static TakeoverStatus fromWire(String? value) {
    if (value == null) return TakeoverStatus.unknown;
    for (final TakeoverStatus s in TakeoverStatus.values) {
      if (s.wireValue == value) return s;
    }
    return TakeoverStatus.unknown;
  }
}

/// Snapshot of a pending/active Line Takeover Request on the line behind this
/// machine, as carried by the shift-line summary response.
///
/// Countdowns are **backend-authoritative**: prefer the absolute [expiresAt] /
/// [handoverExpiresAt] timestamps (resume-safe); fall back to the relative
/// `*RemainingSeconds` anchored to [observedAt] only when the absolute value
/// is absent. The app never decides locally that a request has expired — when
/// a countdown reaches 0 the UI re-fetches the summary for the true status.
@immutable
class LineTakeover {
  const LineTakeover({
    required this.status,
    required this.observedAt,
    this.requestId,
    this.requestedByOperatorName,
    this.currentOperatorName,
    this.expiresAt,
    this.handoverExpiresAt,
    this.remainingSeconds,
    this.handoverRemainingSeconds,
  });

  /// Current request status. Drives the dialog/banner and the work gate.
  final TakeoverStatus status;

  /// When this snapshot was parsed from the REST response — the anchor for
  /// the relative `*RemainingSeconds` fallbacks.
  final DateTime observedAt;

  /// Backend request id (`pendingTakeoverRequest.id`). Used to de-duplicate
  /// the sound/vibration alert and the blocking dialog across refreshes.
  final int? requestId;

  /// Name of the incoming operator who requested the takeover.
  final String? requestedByOperatorName;

  /// Name of the current operator the roll worker must go fetch.
  final String? currentOperatorName;

  /// Absolute end of the 10-minute pending window.
  final DateTime? expiresAt;

  /// Absolute end of the 5-minute post-accept handover window.
  final DateTime? handoverExpiresAt;

  /// Relative seconds left in the pending window (fallback for [expiresAt]).
  final int? remainingSeconds;

  /// Relative seconds left in the handover window (fallback).
  final int? handoverRemainingSeconds;

  /// Resume-safe end of the 10-minute pending window. Absolute timestamp when
  /// available, otherwise [observedAt] + [remainingSeconds].
  DateTime? get effectivePendingExpiry {
    if (expiresAt != null) return expiresAt;
    if (remainingSeconds != null) {
      return observedAt.add(Duration(seconds: remainingSeconds!));
    }
    return null;
  }

  /// Resume-safe end of the 5-minute handover window.
  DateTime? get effectiveHandoverExpiry {
    if (handoverExpiresAt != null) return handoverExpiresAt;
    if (handoverRemainingSeconds != null) {
      return observedAt.add(Duration(seconds: handoverRemainingSeconds!));
    }
    return null;
  }

  /// True while the takeover should still surface a banner (pending, accepted,
  /// or mid-handover auto-release).
  bool get isActive =>
      status == TakeoverStatus.pending ||
      status == TakeoverStatus.accepted ||
      status == TakeoverStatus.timeoutAutoReleased ||
      status == TakeoverStatus.postAcceptTimeoutAutoReleased;

  /// True when the takeover itself forces roll work to stop — the line is
  /// mid-handover, awaiting the incoming operator's claim (spec §8).
  bool get forcesWorkBlock =>
      status == TakeoverStatus.timeoutAutoReleased ||
      status == TakeoverStatus.postAcceptTimeoutAutoReleased;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LineTakeover &&
        other.status == status &&
        other.observedAt == observedAt &&
        other.requestId == requestId &&
        other.requestedByOperatorName == requestedByOperatorName &&
        other.currentOperatorName == currentOperatorName &&
        other.expiresAt == expiresAt &&
        other.handoverExpiresAt == handoverExpiresAt &&
        other.remainingSeconds == remainingSeconds &&
        other.handoverRemainingSeconds == handoverRemainingSeconds;
  }

  @override
  int get hashCode => Object.hash(
    status,
    observedAt,
    requestId,
    requestedByOperatorName,
    currentOperatorName,
    expiresAt,
    handoverExpiresAt,
    remainingSeconds,
    handoverRemainingSeconds,
  );
}
