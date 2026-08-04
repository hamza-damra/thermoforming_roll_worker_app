import 'package:flutter/foundation.dart';

/// Discriminated stream item emitted by `RollWorkerLinesSseClient` — the
/// pre-login global SSE channel (`GET /thermoforming-roll-app/events`).
///
/// The channel is **only a refresh trigger**. No item carries business
/// state: on any [PickerSseRefreshTriggered] (and on (re)connect) the picker
/// re-reads `/bootstrap`, which is the single source of truth.
@immutable
sealed class RollWorkerLinesStreamItem {
  const RollWorkerLinesStreamItem();
}

/// First successful `connected` handshake on a brand-new connection.
class PickerSseConnected extends RollWorkerLinesStreamItem {
  const PickerSseConnected();
}

/// `connected` handshake observed after a prior disconnect / server timeout.
/// The controller refetches `/bootstrap` immediately on this.
class PickerSseReconnected extends RollWorkerLinesStreamItem {
  const PickerSseReconnected();
}

/// Non-fatal transport error. The client keeps reconnecting in the
/// background; surface for telemetry only.
class PickerSseTransportError extends RollWorkerLinesStreamItem {
  const PickerSseTransportError(this.error);
  final Object error;
}

/// Lifecycle step reported by an `urgent-manager-announcement` nudge
/// (announcement-nudge handoff §4.1).
///
/// The frame's `eventType` is a **frozen legacy literal** — it reads
/// `URGENT_MANAGER_ANNOUNCEMENT_CREATED` for every action so deployed builds
/// keep matching it. New code branches on this instead.
///
/// Nothing in the app changes behaviour per action: every value still means
/// "refetch `/pending`" (§11 — refetching is always the safe response). The
/// value is carried for diagnostics only.
enum UrgentAnnouncementAction {
  created('CREATED'),
  updated('UPDATED'),
  deactivated('DEACTIVATED'),
  deleted('DELETED'),

  /// An `action` value the backend introduced after this build. Distinct from
  /// [created] on purpose: an *absent* key means an older backend that only
  /// ever created (§11 "treat as `CREATED`"), whereas an unrecognised *value*
  /// means a newer backend we cannot interpret. Both still refetch.
  unknown('__UNKNOWN__');

  const UrgentAnnouncementAction(this.wireValue);

  /// Backend-side string (e.g. `"DEACTIVATED"`).
  final String wireValue;

  /// Resolves the frame's `action`. A missing key ([wire] == null) maps to
  /// [created] per §11; an unrecognised value maps to [unknown].
  /// Case-sensitive (matches the backend exactly).
  static UrgentAnnouncementAction fromWire(String? wire) {
    if (wire == null || wire.isEmpty) return UrgentAnnouncementAction.created;
    for (final UrgentAnnouncementAction value
        in UrgentAnnouncementAction.values) {
      if (value.wireValue == wire) return value;
    }
    return UrgentAnnouncementAction.unknown;
  }
}

/// A `urgent-manager-announcement` frame arrived — a best-effort nudge to
/// refetch `/urgent-announcements/pending`. It is **additive and distinct**
/// from [PickerSseRefreshTriggered]: it never triggers a bootstrap/sessions
/// refresh. The fields are diagnostic only — the sanitized `/pending`
/// endpoint is authoritative and carries no body/sender either.
class PickerSseUrgentAnnouncement extends RollWorkerLinesStreamItem {
  const PickerSseUrgentAnnouncement({
    this.announcementId,
    this.priority,
    this.action = UrgentAnnouncementAction.created,
  });

  final int? announcementId;
  final String? priority;

  /// What happened to the announcement. Defaults to
  /// [UrgentAnnouncementAction.created] — the pre-`action` backend contract.
  final UrgentAnnouncementAction action;
}

/// A `roll-worker-lines-changed` frame arrived — a plain "refresh now"
/// trigger. The fields below are **diagnostic only** (logging / dedupe);
/// they are never trusted as business state.
class PickerSseRefreshTriggered extends RollWorkerLinesStreamItem {
  const PickerSseRefreshTriggered({
    this.type,
    this.palletizingLineId,
    this.version,
    this.eventId,
    this.occurredAt,
  });

  final String? type;
  final int? palletizingLineId;
  final int? version;
  final String? eventId;
  final DateTime? occurredAt;
}
