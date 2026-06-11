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

  /// e.g. `"URGENT"` — diagnostic only.
  final String? priority;

  @override
  bool operator ==(Object other) =>
      other is ManagerAnnouncement &&
      other.id == id &&
      other.createdAt == createdAt &&
      other.createdAtDisplay == createdAtDisplay &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(id, createdAt, createdAtDisplay, priority);
}
