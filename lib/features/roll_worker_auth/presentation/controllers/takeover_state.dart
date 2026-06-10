import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';

/// Sealed state for the takeover-with-roll-declaration flow on a single
/// shift-line. The takeover card watches this to drive its spinner / button
/// disable and inline error.
@immutable
sealed class TakeoverState {
  const TakeoverState();
}

/// No takeover call in flight; the card shows its two options.
class TakeoverIdle extends TakeoverState {
  const TakeoverIdle();
}

/// The takeover call (and the follow-up re-login) is in flight. Both option
/// buttons are disabled and a spinner shows. Duplicate submits are suppressed.
class TakeoverSubmitting extends TakeoverState {
  const TakeoverSubmitting();
}

/// The takeover or the follow-up re-login failed. The card shows the mapped
/// Arabic message and allows retry (which reuses the same `clientRequestId`).
class TakeoverFailureState extends TakeoverState {
  const TakeoverFailureState(this.failure);
  final AppFailure failure;
}
