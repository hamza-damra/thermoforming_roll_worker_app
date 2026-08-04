/// Central answer to "what *kind* of fault is this?".
///
/// Every Roll Worker endpoint sits behind two independent checks, and the app
/// must react to them differently (announcement-nudge handoff §4.0 / §4.4):
///
/// | Header | Proves | Failure |
/// |---|---|---|
/// | `X-Device-Key` | device identity, enforced by the security chain | [isDeviceAuthFault] |
/// | `X-Session-Token` | the worker's ACTIVE roll-worker session | [isSessionLossCascade] |
///
/// Both surface as HTTP 401, so **branch on `error.code`, never on the status**
/// — `ROLL_WORKER_SESSION_REQUIRED` is 400 for a blank token and 404 for an
/// unknown one, and a device-key failure never reaches the controller at all.
///
/// These predicates live here rather than being re-typed at each call site so
/// adding a future code is a one-line change and no feature can drift out of
/// step with the rest.
library;

import 'app_failure.dart';
import 'error_code.dart';

/// True when the failure means the worker's line session is gone (expired,
/// replaced, ended, or the token never reached the server) **or** the shift
/// line itself is gone/inactive.
///
/// Call sites respond by clearing the stored per-line token and/or calling
/// `MultiLineSessionRegistry.notifySessionLost`, which funnels the worker back
/// to the PIN overlay.
///
/// [ErrorCode.authInvalidCredentials] is deliberately **excluded** — see
/// [isDeviceAuthFault].
bool isSessionLossCascade(AppFailure failure) {
  if (failure is! BusinessFailure) return false;
  return switch (failure.code) {
    ErrorCode.rollWorkerSessionRequired ||
    ErrorCode.rollOpSessionTokenMissing ||
    ErrorCode.thermoformingShiftLineNotFound ||
    ErrorCode.thermoformingShiftLineNotActive => true,
    _ => false,
  };
}

/// True when the shared `X-Device-Key` is missing, empty, or wrong.
///
/// This is a device/configuration fault: the worker's session is perfectly
/// valid and re-authenticating fixes nothing. It must **never** clear a
/// session token or trigger the re-login flow — an app that maps every 401 to
/// "your shift session ended" tells the worker to log in again when the real
/// fault is a misconfigured device.
///
/// Kept as a separate predicate that no cascade site consults, so the
/// exclusion is structural rather than a comment someone can forget.
bool isDeviceAuthFault(AppFailure failure) =>
    failure is BusinessFailure &&
    failure.code == ErrorCode.authInvalidCredentials;
