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
