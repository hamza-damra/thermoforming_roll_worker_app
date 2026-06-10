import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../data/dto/roll_worker_handover_response.dart';

/// Sealed state for the keep-mounted handover flow on a single shift-line.
@immutable
sealed class KeepMountedHandoverState {
  const KeepMountedHandoverState();
}

/// No call in flight; the dialog shows the weight prompt.
class KeepMountedIdle extends KeepMountedHandoverState {
  const KeepMountedIdle();
}

/// The keep-mounted call is in flight. Confirm disabled, duplicate submits
/// suppressed.
class KeepMountedSubmitting extends KeepMountedHandoverState {
  const KeepMountedSubmitting();
}

/// The handover succeeded — the worker's session is ended and the roll stays
/// mounted. The dialog pops with [response]; the caller drops the local
/// session and routes to the PIN overlay.
class KeepMountedSucceeded extends KeepMountedHandoverState {
  const KeepMountedSucceeded(this.response);
  final RollWorkerHandoverResponse response;
}

/// The handover failed — the dialog shows the mapped Arabic message and lets
/// the worker correct the weight / retry.
class KeepMountedHandoverFailure extends KeepMountedHandoverState {
  const KeepMountedHandoverFailure(this.failure);
  final AppFailure failure;
}
