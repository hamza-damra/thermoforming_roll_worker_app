import '../../../core/errors/app_failure.dart';
import 'entities/manager_announcement.dart';

/// Reads the sanitized pending urgent-manager announcements and acknowledges
/// them. Both calls require an active roll-worker session token; the
/// implementation resolves any one of the worker's tokens (the ack is
/// operator-scoped server-side).
abstract class UrgentAnnouncementsRepository {
  /// `GET /urgent-announcements/pending`. Returns the announcements the worker
  /// has not yet acknowledged (oldest first).
  Future<PendingAnnouncementsResult> fetchPending();

  /// `POST /urgent-announcements/{id}/ack`. Idempotent. An unknown id is
  /// surfaced as success (already acked / expired) — see [AckSuccess].
  Future<AckResult> ack(int id);
}

// ─── fetchPending result ────────────────────────────────────────────────────

sealed class PendingAnnouncementsResult {
  const PendingAnnouncementsResult();
}

class PendingAnnouncementsSuccess extends PendingAnnouncementsResult {
  const PendingAnnouncementsSuccess(this.announcements);
  final List<ManagerAnnouncement> announcements;
}

class PendingAnnouncementsFailure extends PendingAnnouncementsResult {
  const PendingAnnouncementsFailure(this.failure);
  final AppFailure failure;
}

// ─── ack result ─────────────────────────────────────────────────────────────

sealed class AckResult {
  const AckResult();
}

/// The notice is acknowledged (or was already gone — `ROLL_ANNOUNCEMENT_NOT_FOUND`
/// is mapped here so the modal dismisses safely).
class AckSuccess extends AckResult {
  const AckSuccess();
}

class AckFailure extends AckResult {
  const AckFailure(this.failure);
  final AppFailure failure;
}
