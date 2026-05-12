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

  // ─── Active shift-line picker ────────────────────────────────────────────

  /// `GET {base}/shift-lines/active-options`.
  /// Headers: X-Device-Key only. Reachable before roll-worker auth — does
  /// NOT require an X-Session-Token. Returns the list of currently-ACTIVE
  /// Thermoforming shift-lines that the operator app has opened against the
  /// current shift.
  static const String activeShiftLineOptions =
      '$_rollAppBase/shift-lines/active-options';

  // ─── Roll-worker authentication (multi-line batch) ────────────────────────

  /// `POST {base}/sessions/start-batch`.
  /// Headers: X-Device-Key. Body: `{ "pin": "...", "shiftLineIds": [...] }`.
  /// Atomic: any error rejects the whole batch and opens no session.
  /// Source of truth for new code; the legacy single-line auth endpoint
  /// below is retained for backward compatibility only.
  static const String sessionsStartBatch =
      '$_rollAppBase/sessions/start-batch';

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

  // ─── Product switch ───────────────────────────────────────────────────────
  //
  // NOTE: there is a documented BACKEND GAP for the allowed-products list
  // (`/product-switch-options`). The product-switch _action_ endpoint below
  // exists, but the Roll Worker app blocks the flow in UI until the picker
  // gap closes. See plan §7 (Stage 7).

  /// `POST {base}/shift-lines/{shiftLineId}/product-switch`.
  /// Body: `{ "newProductTypeId": <int>, "currentRollWeightKg": <num> }`.
  static String productSwitch(int shiftLineId) =>
      '$_rollAppBase/shift-lines/$shiftLineId/product-switch';

  // ─── Roll label reprint ───────────────────────────────────────────────────

  /// `GET {base}/rolls/{generatedRollId}/reprint-label`.
  /// Looser session check (any active roll-worker session is accepted).
  static String reprintRollLabel(String generatedRollId) =>
      '$_rollAppBase/rolls/$generatedRollId/reprint-label';
}

/// Documented backend gaps. These intentionally have NO callable client in
/// Stage 2 — the Roll Worker app shows safe blocked UI for each.
///
/// Tracked in plan §4 / requirements §24.
class BackendGapPaths {
  BackendGapPaths._();

  /// §11 / §24 gap #2 — products allowed for product-switch on the line.
  /// Suggested: `GET .../shift-lines/{shiftLineId}/product-switch-options`.
  static const String productSwitchOptions =
      'GAP: GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/product-switch-options';

  /// §13 / §24 gap #3 — read-only current mounted roll on a line.
  /// Suggested: `GET .../shift-lines/{shiftLineId}/current-roll`.
  static const String currentMountedRoll =
      'GAP: GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/current-roll';
}
