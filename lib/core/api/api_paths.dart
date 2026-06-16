/// Backend endpoint paths used by the Roll Worker app.
///
/// Source of truth:
/// `docs/THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md` §14.
///
/// Only the endpoints implemented and approved for this app live here.
/// Any path under `/api/v1/thermoforming-app/...` (Operator App) or
/// `/api/v1/palletizing-line/...` (Palletizing App) is intentionally absent
/// — see the forbidden-API grep enforced by Stage 9 verification.
class ApiPaths {
  ApiPaths._();

  static const String _rollAppBase = '/api/v1/thermoforming-roll-app';

  // ─── Pre-login bootstrap (REST-authoritative picker) ─────────────────────

  /// `GET {base}/bootstrap`.
  /// Headers: X-Device-Key only. Reachable before roll-worker auth — does
  /// NOT require an X-Session-Token. Read-only: creates no session and
  /// mutates no production state. Returns ONE row per active thermoforming
  /// machine, keyed by a stable `thermoformingLineId` (rows never appear /
  /// disappear as operators come and go — they change state). This is the
  /// authoritative source for the pre-login picker.
  static const String rollWorkerBootstrap = '$_rollAppBase/bootstrap';

  /// `GET {base}/events`.
  /// Headers: X-Device-Key only. ONE global SSE stream for the whole
  /// pre-login picker (not per-line). Every frame is only a "refresh now"
  /// trigger — it carries no business state. The REST `/bootstrap` response
  /// is the source of truth; on any frame the picker re-reads `/bootstrap`.
  static const String rollWorkerEvents = '$_rollAppBase/events';

  // ─── Roll-worker authentication (multi-line batch) ────────────────────────

  /// `POST {base}/sessions/start-batch`.
  /// Headers: X-Device-Key. Body: `{ "pin": "...", "shiftLineIds": [...] }`.
  /// Atomic: any error rejects the whole batch and opens no session.
  /// Source of truth for new code; the legacy single-line auth endpoint
  /// below is retained for backward compatibility only.
  static const String sessionsStartBatch = '$_rollAppBase/sessions/start-batch';

  // V109: the login-time takeover endpoint
  // (`POST /sessions/takeover-with-roll-declaration`) is intentionally NOT
  // declared here. Mounted-roll ownership moved to the line/operator-shift
  // context; login while a roll is mounted now succeeds on the normal
  // start-batch path, so the app never invokes the takeover endpoint.

  /// `GET {base}/sessions/me`.
  /// Headers: X-Device-Key + X-Session-Token (any of the worker's tokens).
  /// Returns the worker's identity plus a per-line snapshot (mounted roll,
  /// active product, blocked / handover / takeover, lifecycle) for every
  /// ACTIVE session. Authoritative post-login state — one round-trip
  /// replaces the per-line `/current` loop.
  static const String sessionsMe = '$_rollAppBase/sessions/me';

  /// `GET {base}/sessions/me/joinable-lines`.
  /// Headers: X-Device-Key + X-Session-Token. Returns every ACTIVE
  /// shift-line minus the lines the worker already owns — feeds the
  /// in-session "add another line" picker.
  static const String sessionsMeJoinableLines =
      '$_rollAppBase/sessions/me/joinable-lines';

  /// `POST {base}/sessions/leave-all`.
  /// Headers: X-Device-Key + X-Session-Token. Empty body. Returns 204.
  /// Idempotent: returns 204 even when zero sessions are active.
  static const String sessionsLeaveAll = '$_rollAppBase/sessions/leave-all';

  // ─── Roll-worker per-shift-line session restore + logout ──────────────────

  /// `GET {base}/shift-lines/{shiftLineId}/roll-worker-session/current`.
  /// Headers: X-Device-Key (NO X-Session-Token — discovery mode).
  static String rollWorkerSessionCurrent(int shiftLineId) =>
      '$_rollAppBase/shift-lines/$shiftLineId/roll-worker-session/current';

  /// `POST {base}/shift-lines/{shiftLineId}/roll-worker-logout`.
  /// Headers: X-Device-Key. Body: `{ "sessionToken": "..." }` (token in body).
  static String rollWorkerLogout(int shiftLineId) =>
      '$_rollAppBase/shift-lines/$shiftLineId/roll-worker-logout';

  // ─── Shift-line summary ──────────────────────────────────────────────────────

  /// `GET {base}/shift-lines/{shiftLineId}/summary`.
  /// Headers: X-Device-Key, X-Session-Token.
  /// Returns completed-roll counters and the currently mounted roll snapshot.
  static String shiftLineSummary(int shiftLineId) =>
      '$_rollAppBase/shift-lines/$shiftLineId/summary';

  // ─── Roll mount / scan ────────────────────────────────────────────────────

  /// `POST {base}/shift-lines/{shiftLineId}/scan-roll`.
  /// Headers: X-Device-Key, X-Session-Token. Body: `{ "generatedRollId": "..." }`.
  static String scanRoll(int shiftLineId) =>
      '$_rollAppBase/shift-lines/$shiftLineId/scan-roll';

  // ─── Previous-roll resolution ─────────────────────────────────────────────

  /// `POST {base}/shift-lines/{shiftLineId}/previous-roll/full-consume`.
  static String previousRollFullConsume(int shiftLineId) =>
      '$_rollAppBase/shift-lines/$shiftLineId/previous-roll/full-consume';

  /// `POST {base}/shift-lines/{shiftLineId}/previous-roll/return`.
  /// Body: `{ "remainingWeightKg": <num> }`.
  static String previousRollReturn(int shiftLineId) =>
      '$_rollAppBase/shift-lines/$shiftLineId/previous-roll/return';

  /// `POST {base}/shift-lines/{shiftLineId}/previous-roll/grinding`.
  /// Body: `{ "remainingWeightKg": <num> }`.
  static String previousRollGrinding(int shiftLineId) =>
      '$_rollAppBase/shift-lines/$shiftLineId/previous-roll/grinding';

  // ─── Roll label reprint ───────────────────────────────────────────────────

  /// `GET {base}/rolls/{generatedRollId}/reprint-label`.
  /// Looser session check (any active roll-worker session is accepted).
  static String reprintRollLabel(String generatedRollId) =>
      '$_rollAppBase/rolls/$generatedRollId/reprint-label';

  // ─── Urgent manager announcements (sanitized) ───────────────────────────
  //
  // THERMOFORMING manager announcements surface to the Roll Worker app as a
  // SANITIZED generic notice only — never the real body or sender. Both
  // endpoints require X-Device-Key + X-Session-Token (any active roll-worker
  // session token). The ack is idempotent and keyed server-side by the
  // worker's operator id, so one ack dismisses the notice across every line
  // session the worker holds. See
  // `docs/ROLL_WORKER_URGENT_ANNOUNCEMENTS_AND_SHIFT_END_HANDOFF.md`.

  /// `GET {base}/urgent-announcements/pending`.
  /// Headers: X-Device-Key, X-Session-Token. Returns the active, not-expired,
  /// not-yet-acked-by-this-worker announcements (oldest first) as a list of
  /// sanitized DTOs — fixed generic `title`/`message`, no body/sender. This
  /// is the authoritative source; the SSE nudge below is best-effort.
  static const String urgentAnnouncementsPending =
      '$_rollAppBase/urgent-announcements/pending';

  /// `POST {base}/urgent-announcements/{id}/ack`.
  /// Headers: X-Device-Key, X-Session-Token. Empty body. Backend forces
  /// `acknowledgementType = GENERIC_NOTICE_ACK`, keyed by operator id.
  /// Duplicate acks return success (idempotent); an unknown id →
  /// `ROLL_ANNOUNCEMENT_NOT_FOUND`.
  static String urgentAnnouncementAck(int id) =>
      '$_rollAppBase/urgent-announcements/$id/ack';

  // ─── Operator-dashboard SSE (cross-app realtime sync) ────────────────────
  //
  // SSE channel emitted by the operator app's palletizing-line backend, used
  // by the Roll Worker app to reflect roll-state / active-product changes the
  // operator triggers — see `docs/HANDOFF_ROLL_EMPLOYEE_APP.md`. This is the
  // ONE permitted entry into the `/api/v1/palletizing-line/...` namespace
  // because the SSE channel is the cross-app sync surface; no other path
  // under that namespace may be added. Read-only stream — never mutates.
  static const String _palletizingLineBase = '/api/v1/palletizing-line';

  /// `GET {palletizing-line}/lines/{lineId}/operator-dashboard/events`.
  ///
  /// `lineId` is the **palletizing line id** carried in
  /// `RollWorkerSession.palletizingLineId`. Headers: X-Device-Key,
  /// X-Session-Token. Server emits `connected` once on subscribe, then
  /// `operator-dashboard-changed` frames whenever the operator changes the
  /// product or the mounted roll state. Heartbeats are `: ping` comments
  /// every 25s; the emitter recycles after 5 minutes so the client must
  /// reconnect.
  static String operatorDashboardEvents(int lineId) =>
      '$_palletizingLineBase/lines/$lineId/operator-dashboard/events';
}

/// Documented backend gaps. These intentionally have NO callable client in
/// Stage 2 — the Roll Worker app shows safe blocked UI for each.
///
/// Tracked in plan §4 / requirements §24.
class BackendGapPaths {
  BackendGapPaths._();

  /// §13 / §24 gap #3 — read-only current mounted roll on a line.
  /// Suggested: `GET .../shift-lines/{shiftLineId}/current-roll`.
  static const String currentMountedRoll =
      'GAP: GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/current-roll';
}
