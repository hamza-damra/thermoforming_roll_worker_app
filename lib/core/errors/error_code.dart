/// Backend error codes returned in the `{success:false, error:{code, message}}`
/// envelope. Mirrors the codes documented in
/// `docs/THERMOFORMING_ROLL_WORKER_APP_FRONTEND_REQUIREMENTS.md` §17.
///
/// Add new codes here when the backend introduces them; never invent codes.
enum ErrorCode {
  // ─── Roll-worker auth / session ───────────────────────────────────────────
  rollWorkerNotAllowed('ROLL_WORKER_NOT_ALLOWED'),
  rollWorkerSessionRequired('ROLL_WORKER_SESSION_REQUIRED'),
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

  // ─── Roll lifecycle ───────────────────────────────────────────────────────
  rollNotFound('ROLL_NOT_FOUND'),
  rollAlreadyConsumed('ROLL_ALREADY_CONSUMED'),
  rollActiveOnAnotherLine('ROLL_ACTIVE_ON_ANOTHER_LINE'),
  rollBlocked('ROLL_BLOCKED'),
  rollTypeNotAllowedForProduct('ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT'),
  noActiveRollOnLine('NO_ACTIVE_ROLL_ON_LINE'),
  noOpenSegmentOnItem('NO_OPEN_SEGMENT_ON_ITEM'),

  // ─── Weight inputs ────────────────────────────────────────────────────────
  invalidRemainingRollWeight('INVALID_REMAINING_ROLL_WEIGHT'),
  currentRollWeightRequired('CURRENT_ROLL_WEIGHT_REQUIRED'),
  invalidCurrentRollWeight('INVALID_CURRENT_ROLL_WEIGHT'),

  // ─── Product switch ───────────────────────────────────────────────────────
  productTypeNotFound('PRODUCT_TYPE_NOT_FOUND'),
  productTypeInactive('PRODUCT_TYPE_INACTIVE'),

  // ─── Reprint ──────────────────────────────────────────────────────────────
  rollLabelReprintNotAvailable('ROLL_LABEL_REPRINT_NOT_AVAILABLE'),

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
