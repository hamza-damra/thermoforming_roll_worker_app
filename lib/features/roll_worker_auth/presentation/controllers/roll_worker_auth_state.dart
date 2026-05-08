import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/roll_worker_session.dart';

/// Auth state for a single shift-line. Sealed so the UI must handle every
/// branch via a `switch` expression.
@immutable
sealed class RollWorkerAuthState {
  const RollWorkerAuthState();
}

/// First-paint state before any session check has run.
class RollWorkerAuthInitial extends RollWorkerAuthState {
  const RollWorkerAuthInitial();
}

/// Calling `GET /roll-worker-session/current` to discover whether a session
/// already exists for this shift-line.
class RollWorkerAuthChecking extends RollWorkerAuthState {
  const RollWorkerAuthChecking();
}

/// No active session. PIN screen is shown.
///
/// [lastFailure] is set when the user's previous login attempt failed, so
/// the PIN screen can render an inline Arabic error.
///
/// [silentSessionLoss] is `true` when this state was reached via a silent
/// cascade — i.e. the discovery `GET /roll-worker-session/current` returned
/// `ROLL_WORKER_SESSION_REQUIRED` while the worker had been authenticated.
/// The bootstrap screen surfaces a snackbar for this case but NOT for a
/// deliberate logout (where the flag is `false`).
class RollWorkerAuthUnauthenticated extends RollWorkerAuthState {
  const RollWorkerAuthUnauthenticated({
    this.lastFailure,
    this.silentSessionLoss = false,
  });

  final AppFailure? lastFailure;
  final bool silentSessionLoss;
}

/// Login request in flight. PIN button shows a spinner; further taps are
/// suppressed by the controller (duplicate-submit guard).
class RollWorkerAuthAuthenticating extends RollWorkerAuthState {
  const RollWorkerAuthAuthenticating();
}

/// Active authenticated session. UI shows the home / mount card.
class RollWorkerAuthAuthenticated extends RollWorkerAuthState {
  const RollWorkerAuthAuthenticated(this.session);

  final RollWorkerSession session;
}

/// Shift-line was ended elsewhere (cascade-on-end) or is no longer found.
/// UI clears the token and routes back to the waiting screen.
class RollWorkerAuthLineGone extends RollWorkerAuthState {
  const RollWorkerAuthLineGone();
}
