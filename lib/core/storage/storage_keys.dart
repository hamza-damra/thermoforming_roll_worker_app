/// Storage key conventions used across the app. Centralised so collisions
/// can't sneak in.
class StorageKeys {
  StorageKeys._();

  /// Roll-worker session token, scoped per shift-line.
  ///
  /// Source of truth: requirements §6 / §15. Roll-worker sessions are
  /// per-shift-line, NEVER global — the same operator on a different line
  /// gets a different session and a different token.
  static String rollWorkerSessionToken(int shiftLineId) =>
      'roll_worker_session_token_$shiftLineId';

  /// Last shift-line id selected by this device, used purely as a UX hint on
  /// app resume to skip the picker if the line is still active. Not security
  /// sensitive — stored alongside but separate from the session token.
  ///
  /// (Will be wired in Stage 4 when the picker / waiting screen lands.)
  static const String selectedShiftLineId = 'selected_shift_line_id';

  /// JSON-encoded list of shift-line ids the device currently holds an
  /// active roll-worker session for. Read on app launch to drive
  /// per-line `/current` restoration; written on every batch-start and
  /// every per-line logout/cascade-loss.
  static const String rollWorkerActiveShiftLineIds =
      'roll_worker_active_shift_line_ids';
}
