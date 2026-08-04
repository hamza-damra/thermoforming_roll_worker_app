import 'package:flutter/foundation.dart';

/// A sanitized urgent manager announcement surfaced to the roll worker.
///
/// PRIVACY (structural): this entity deliberately carries **no** real
/// `title`, `message`, `messageBody`, or `senderDisplayName` field. The
/// Roll Worker app only ever shows a fixed generic notice (see
/// `UrgentAnnouncementStrings`), so there is intentionally nowhere to put the
/// manager's actual content — even if a future backend bug were to send it,
/// it cannot be parsed into, or rendered from, this entity.
///
/// `createdAtDisplay` is the only server-provided text rendered, and only as
/// secondary metadata. `priority`/`createdAt` are kept for telemetry and a
/// defensive client-side oldest-first ordering.
@immutable
class ManagerAnnouncement {
  const ManagerAnnouncement({
    required this.id,
    this.createdAt,
    this.createdAtDisplay,
    this.expiresAt,
    this.expiresAtDisplay,
    this.priority,
  });

  /// Stable announcement id — used to acknowledge via
  /// `POST /urgent-announcements/{id}/ack`.
  final int id;

  /// Server timestamp (UTC) — diagnostic / defensive ordering only.
  final DateTime? createdAt;

  /// Pre-formatted Arabic display timestamp (e.g. `"2026-06-10، 06:10 مساءً"`).
  /// The only server text the UI renders, shown as secondary metadata.
  final String? createdAtDisplay;

  /// Absolute expiry (UTC), or null when the notice never expires
  /// (timed-announcements handoff §4.2 — also null on a legacy row).
  ///
  /// The server already excludes expired rows from `/pending`, so this is
  /// **not** a filter applied on arrival; it only lets the controller arm a
  /// one-shot timer so the blocking modal clears at the exact second instead
  /// of waiting for the next nudge / resume / reconnect.
  final DateTime? expiresAt;

  /// Pre-formatted Arabic expiry timestamp. Parsed for contract parity and
  /// diagnostics; deliberately **not** rendered — the modal's visible surface
  /// stays the two fixed strings plus [createdAtDisplay].
  final String? expiresAtDisplay;

  /// e.g. `"URGENT"` — diagnostic only.
  final String? priority;

  @override
  bool operator ==(Object other) =>
      other is ManagerAnnouncement &&
      other.id == id &&
      other.createdAt == createdAt &&
      other.createdAtDisplay == createdAtDisplay &&
      other.expiresAt == expiresAt &&
      other.expiresAtDisplay == expiresAtDisplay &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    createdAtDisplay,
    expiresAt,
    expiresAtDisplay,
    priority,
  );
}
