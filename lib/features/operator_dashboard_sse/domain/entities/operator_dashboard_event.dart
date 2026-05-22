import 'package:flutter/foundation.dart';

/// Top-level reason for an `operator-dashboard-changed` SSE frame.
///
/// Only the reasons the Roll Worker app reacts to are enumerated. Anything
/// else surfaces as [OperatorDashboardReason.unknown] and the sync
/// controller falls back to a REST refetch.
enum OperatorDashboardReason {
  productChanged('PRODUCT_CHANGED'),
  rollConsumptionSegmentRecorded('ROLL_CONSUMPTION_SEGMENT_RECORDED'),
  rollContinuedWithNewProduct('ROLL_CONTINUED_WITH_NEW_PRODUCT'),
  rollReturnedRemaining('ROLL_RETURNED_REMAINING'),
  machineRollStateUpdated('MACHINE_ROLL_STATE_UPDATED'),

  // Line Takeover Request events (spec §6). None carry a typed payload — the
  // takeover state lives on the REST shift-line summary, so each of these
  // simply triggers a summary refetch via the notification-only path.
  lineTakeoverRequested('LINE_TAKEOVER_REQUESTED'),
  lineTakeoverAccepted('LINE_TAKEOVER_ACCEPTED'),
  lineTakeoverRejected('LINE_TAKEOVER_REJECTED'),
  lineTakeoverTimeoutAutoReleased('LINE_TAKEOVER_TIMEOUT_AUTO_RELEASED'),
  lineTakeoverPostAcceptTimeoutAutoReleased(
    'LINE_TAKEOVER_POST_ACCEPT_TIMEOUT_AUTO_RELEASED',
  ),
  lineTakeoverCompleted('LINE_TAKEOVER_COMPLETED'),
  lineStateChanged('LINE_STATE_CHANGED'),

  // Operator-assignment events on the line. Like the line-state / takeover
  // reasons these carry no typed payload — they route through the
  // notification-only path so the sync controller refetches the REST summary.
  rollsEmployeeChanged('ROLLS_EMPLOYEE_CHANGED'),
  palletizingEmployeeChanged('PALLETIZING_EMPLOYEE_CHANGED'),

  unknown('UNKNOWN');

  const OperatorDashboardReason(this.wireValue);
  final String wireValue;

  static OperatorDashboardReason fromWire(String? value) {
    if (value == null) return OperatorDashboardReason.unknown;
    for (final OperatorDashboardReason r in OperatorDashboardReason.values) {
      if (r.wireValue == value) return r;
    }
    return OperatorDashboardReason.unknown;
  }
}

/// Discriminated union of operator-dashboard payloads.
///
/// The frame's `data` block is parsed into one of these subtypes based on
/// the frame's [OperatorDashboardReason]. When `data` is absent or any
/// required field is null, the sync controller treats the frame as a
/// notification-only hint and falls back to a REST refetch (handoff §7).
@immutable
sealed class OperatorDashboardPayload {
  const OperatorDashboardPayload();
}

class ProductChangedPayload extends OperatorDashboardPayload {
  const ProductChangedPayload({
    required this.machineId,
    required this.newProductId,
    required this.newProductName,
    this.oldProductId,
    this.oldProductName,
    this.changedBy,
    this.currentRollId,
    this.compatibilityResult,
  });

  final int machineId;
  final int? oldProductId;
  final String? oldProductName;
  final int newProductId;
  final String newProductName;
  final int? changedBy;
  final int? currentRollId;

  /// `"compatible"`, `"incompatible"`, or `"no_roll"`. Treated as a
  /// best-effort hint — UI never branches on it directly because the
  /// subsequent typed event (continued vs returned) is the source of truth.
  final String? compatibilityResult;
}

class RollConsumptionSegmentRecordedPayload extends OperatorDashboardPayload {
  const RollConsumptionSegmentRecordedPayload({
    required this.machineId,
    required this.rollId,
    required this.productId,
    required this.productName,
    required this.previousWeight,
    required this.currentWeight,
    required this.consumedWeight,
  });

  final int machineId;
  final int rollId;
  final int productId;
  final String productName;
  final double previousWeight;
  final double currentWeight;
  final double consumedWeight;
}

class RollContinuedWithNewProductPayload extends OperatorDashboardPayload {
  const RollContinuedWithNewProductPayload({
    required this.machineId,
    required this.rollId,
    required this.rollNumber,
    required this.newProductId,
    required this.newProductName,
    required this.currentWeight,
    required this.mounted,
  });

  final int machineId;
  final int rollId;

  /// Generated roll number (PPPSSSSSSSSS) — the 12-digit human-readable id.
  final String rollNumber;

  final int newProductId;
  final String newProductName;
  final double currentWeight;
  final bool mounted;
}

class RollReturnedRemainingPayload extends OperatorDashboardPayload {
  const RollReturnedRemainingPayload({
    required this.machineId,
    required this.rollId,
    required this.rollNumber,
    required this.returnedWeight,
    required this.canPrintLabel,
    required this.mounted,
    this.oldProductId,
    this.oldProductName,
    this.newProductId,
    this.newProductName,
    this.labelId,
  });

  final int machineId;
  final int rollId;
  final String rollNumber;
  final double returnedWeight;
  final int? oldProductId;
  final String? oldProductName;
  final int? newProductId;
  final String? newProductName;

  /// Reserved for future synchronous label generation — always null today.
  final int? labelId;

  /// When true, the reprint affordance is surfaced on the returned-roll card.
  final bool canPrintLabel;
  final bool mounted;
}

/// `MACHINE_ROLL_STATE_UPDATED` — the post-switch authoritative snapshot.
///
/// Idempotent by design: it carries everything needed to converge the UI
/// without an extra REST call. Any client that missed an intermediate event
/// can use this to resync.
class MachineRollStateUpdatedPayload extends OperatorDashboardPayload {
  const MachineRollStateUpdatedPayload({
    required this.machineId,
    this.activeProductId,
    this.activeProductName,
    this.mountedRollId,
    this.mountedRollNumber,
    this.mountedRollCurrentWeight,
    this.mountedRollCompatibleWithActiveProduct,
    this.lastAction,
  });

  final int machineId;
  final int? activeProductId;
  final String? activeProductName;
  final int? mountedRollId;
  final String? mountedRollNumber;
  final double? mountedRollCurrentWeight;
  final bool? mountedRollCompatibleWithActiveProduct;

  /// e.g. `"product_switch_roll_continued"` or
  /// `"product_switch_roll_returned"`. Used by the UI to surface
  /// branch-specific affordances (reprint card on the returned branch).
  final String? lastAction;

  /// Convenience: true when the snapshot says no roll is currently mounted.
  bool get hasNoMount => mountedRollId == null;
}

/// Wrapping frame for an `operator-dashboard-changed` SSE event.
///
/// [payload] is null when the backend omitted `data` (notification-only
/// hint) OR when the payload failed strict parsing — in either case the
/// caller falls back to a REST refetch.
@immutable
class OperatorDashboardEvent {
  const OperatorDashboardEvent({
    required this.lineId,
    required this.reason,
    required this.affected,
    this.version,
    this.eventId,
    this.occurredAt,
    this.payload,
  });

  final int lineId;
  final OperatorDashboardReason reason;
  final List<String> affected;
  final int? version;
  final String? eventId;
  final DateTime? occurredAt;
  final OperatorDashboardPayload? payload;

  /// True when the wrapping frame is intelligible but the typed payload
  /// could not be reconstructed — caller should fall back to a REST
  /// refetch (handoff §7).
  bool get isNotificationOnly => payload == null;
}

/// Discriminated stream item emitted by `OperatorDashboardSseClient`.
///
/// Distinguishes between raw protocol events (`connected`, reconnect) and
/// the real `operator-dashboard-changed` event so callers can refetch
/// state on every fresh subscribe (handoff §6).
@immutable
sealed class OperatorDashboardStreamItem {
  const OperatorDashboardStreamItem();
}

/// First successful handshake on a brand-new connection.
class SseConnected extends OperatorDashboardStreamItem {
  const SseConnected();
}

/// Re-established connection after a drop or 5-minute server timeout.
/// The sync controller refetches REST state when this is observed.
class SseReconnected extends OperatorDashboardStreamItem {
  const SseReconnected();
}

/// Typed dashboard event — caller dispatches by `event.reason`.
class SseEventReceived extends OperatorDashboardStreamItem {
  const SseEventReceived(this.event);
  final OperatorDashboardEvent event;
}

/// Non-fatal transport error. The client will continue reconnecting in
/// the background; surface for telemetry only.
class SseTransportError extends OperatorDashboardStreamItem {
  const SseTransportError(this.error);
  final Object error;
}
