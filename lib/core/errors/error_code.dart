/// Backend error codes returned in the `{success:false, error:{code, message}}`
/// envelope. Mirrors the codes documented in
/// `docs/THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md` §17.
///
/// Add new codes here when the backend introduces them; never invent codes.
enum ErrorCode {
  // ─── Device / transport auth ──────────────────────────────────────────────
  /// The shared `X-Device-Key` is missing, empty, or wrong. The security
  /// filter chain rejects the request (401) *before* the controller runs, so
  /// this is a **device/configuration fault, never a session fault** — it must
  /// not clear a session token or force the worker to re-authenticate. See
  /// `isDeviceAuthFault` in `failure_classification.dart`.
  ///
  /// No bearer/JWT auth exists on any Roll Worker path, so on this app the
  /// code can only ever mean the device key.
  authInvalidCredentials('AUTH_INVALID_CREDENTIALS'),

  // ─── Roll-worker auth / session ───────────────────────────────────────────
  rollWorkerNotAllowed('ROLL_WORKER_NOT_ALLOWED'),
  rollWorkerSessionRequired('ROLL_WORKER_SESSION_REQUIRED'),

  /// The `X-Session-Token` header was absent from the request entirely (400,
  /// Spring's missing-required-header path). Strictly a client bug rather than
  /// a shift-ended condition, but it is routed through the normal session-loss
  /// flow so the worker gets a usable next step instead of a dead screen; the
  /// distinct code keeps it greppable in the logs.
  rollOpSessionTokenMissing('ROLL_OP_SESSION_TOKEN_MISSING'),

  operatorPinInvalid('OPERATOR_PIN_INVALID'),
  operatorPinLocked('OPERATOR_PIN_LOCKED'),

  /// Multi-line batch-start lockout. Wire-distinct from
  /// [operatorPinLocked]; UI maps both to the same Arabic locked message.
  operatorLocked('OPERATOR_LOCKED'),

  // ─── Multi-line batch session-start ───────────────────────────────────────
  rollWorkerSessionBatchEmpty('ROLL_WORKER_SESSION_BATCH_EMPTY'),
  rollWorkerSessionLineDuplicate('ROLL_WORKER_SESSION_LINE_DUPLICATE'),
  rollWorkerSessionLineInactive('ROLL_WORKER_SESSION_LINE_INACTIVE'),
  rollWorkerSessionLineUsedByOtherWorker(
    'ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER',
  ),

  // ─── Shift-line state ─────────────────────────────────────────────────────
  thermoformingShiftLineNotFound('THERMOFORMING_SHIFT_LINE_NOT_FOUND'),
  thermoformingShiftLineNotActive('THERMOFORMING_SHIFT_LINE_NOT_ACTIVE'),
  noCurrentProductOnLine('NO_CURRENT_PRODUCT_ON_LINE'),

  /// Backend rejects roll-mount when the line has no active production-plan
  /// item. Documented in the realtime+line-management handoff §7.1.
  productionPlanItemRequired('PRODUCTION_PLAN_ITEM_REQUIRED'),

  // ─── Roll lifecycle ───────────────────────────────────────────────────────
  rollNotFound('ROLL_NOT_FOUND'),
  rollAlreadyConsumed('ROLL_ALREADY_CONSUMED'),
  rollSentToGrindingNotReusable('ROLL_SENT_TO_GRINDING_NOT_REUSABLE'),
  rollActiveOnAnotherLine('ROLL_ACTIVE_ON_ANOTHER_LINE'),
  rollBlocked('ROLL_BLOCKED'),
  rollTypeNotAllowedForProduct('ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT'),
  rollCuringMinimumNotMet('ROLL_CURING_MINIMUM_NOT_MET'),
  noActiveRollOnLine('NO_ACTIVE_ROLL_ON_LINE'),
  noOpenSegmentOnItem('NO_OPEN_SEGMENT_ON_ITEM'),

  /// Scan/mount rejected because the roll was cancelled by an admin (V127).
  /// Carries a `details` payload (`cancelledBy`, `cancelReason`, `cancelledAt`,
  /// …) the app renders in a dedicated dialog.
  rollAdminCancelled('ROLL_ADMIN_CANCELLED'),

  /// Scan/mount rejected because the roll was reconciled out of physical
  /// inventory (V132). Terminal for mounting, like [rollAdminCancelled], but
  /// the envelope carries `details: null` — there is no payload to render.
  rollReconciledOutOfStock('ROLL_RECONCILED_OUT_OF_STOCK'),

  // ─── Weight inputs ────────────────────────────────────────────────────────
  invalidRemainingRollWeight('INVALID_REMAINING_ROLL_WEIGHT'),
  currentRollWeightRequired('CURRENT_ROLL_WEIGHT_REQUIRED'),
  invalidCurrentRollWeight('INVALID_CURRENT_ROLL_WEIGHT'),

  // ─── Previous-roll close reasons (V127, now required) ─────────────────────
  /// `/previous-roll/return` was called with a blank/whitespace-only reason.
  rollReturnReasonRequired('ROLL_RETURN_REASON_REQUIRED'),

  /// `/previous-roll/grinding` was called with a blank/whitespace-only reason.
  rollGrindingReasonRequired('ROLL_GRINDING_REASON_REQUIRED'),

  // ─── Product switch ───────────────────────────────────────────────────────
  productTypeNotFound('PRODUCT_TYPE_NOT_FOUND'),
  productTypeInactive('PRODUCT_TYPE_INACTIVE'),

  // ─── Reprint ──────────────────────────────────────────────────────────────
  rollLabelReprintNotAvailable('ROLL_LABEL_REPRINT_NOT_AVAILABLE'),

  // ─── Urgent manager announcements ─────────────────────────────────────────
  /// The announcement id passed to `/urgent-announcements/{id}/ack` is not a
  /// known announcement (already expired / acked elsewhere). The notice
  /// controller treats this as already-acknowledged and dismisses safely.
  rollAnnouncementNotFound('ROLL_ANNOUNCEMENT_NOT_FOUND'),

  // ─── Generic ──────────────────────────────────────────────────────────────
  validationError('VALIDATION_ERROR'),

  /// Catch-all for codes not yet enumerated. The wire string is preserved on
  /// the failure for support/debugging; UI shows a generic Arabic message.
  unknown('__UNKNOWN__');

  const ErrorCode(this.wireValue);

  /// Backend-side string (e.g. `"ROLL_WORKER_NOT_ALLOWED"`).
  final String wireValue;

  /// Resolves a backend code string to an [ErrorCode], or [unknown] if the
  /// code is not in the enum. Case-sensitive (matches backend exactly).
  static ErrorCode fromWire(String? code) {
    if (code == null || code.isEmpty) return ErrorCode.unknown;
    for (final ErrorCode value in ErrorCode.values) {
      if (value.wireValue == code) return value;
    }
    return ErrorCode.unknown;
  }
}
