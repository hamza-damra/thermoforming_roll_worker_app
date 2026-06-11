import 'package:flutter/foundation.dart';

import '../../domain/entities/roll_worker_session.dart';

/// Per-line logout status. Drives the warning tint + retry affordance on
/// chips whose previous logout call failed.
enum LineLogoutStatus { idle, loggingOut, failedRetryable }

/// One-shot registry events. The bootstrap snackbar listener inspects
/// [lastEvent] on every state change; the registry clears it after each
/// emit so a rebuild doesn't re-fire the same event.
@immutable
sealed class RegistryEvent {
  const RegistryEvent();
}

class LineLost extends RegistryEvent {
  const LineLost(this.shiftLineId);
  final int shiftLineId;
}

class BatchAdded extends RegistryEvent {
  const BatchAdded(this.shiftLineIds);
  final Set<int> shiftLineIds;
}

class DeliberateLogout extends RegistryEvent {
  const DeliberateLogout(this.shiftLineId);
  final int shiftLineId;
}

class PartialLogoutAll extends RegistryEvent {
  const PartialLogoutAll({required this.failed});
  final Set<int> failed;
}

/// Sealed top-level state for the multi-line session registry.
@immutable
sealed class MultiLineSessionRegistryState {
  const MultiLineSessionRegistryState();
}

/// Cold-start: parallel `/current` calls are in flight.
class RegistryRestoring extends MultiLineSessionRegistryState {
  const RegistryRestoring({this.restoredIds = const <int>{}});
  final Set<int> restoredIds;
}

/// No active sessions. Bootstrap routes to picker (or PIN if a picker
/// selection is pending).
class RegistryEmpty extends MultiLineSessionRegistryState {
  const RegistryEmpty({this.lastEvent});
  final RegistryEvent? lastEvent;
}

/// At least one active session. [activeShiftLineId] is the chip currently
/// rendered by [MultiLineHomeShell]; switching is a pointer move only.
class RegistryActive extends MultiLineSessionRegistryState {
  const RegistryActive({
    required this.sessions,
    required this.activeShiftLineId,
    required this.logoutStatus,
    this.lastEvent,
  });

  final Map<int, RollWorkerSession> sessions;
  final int activeShiftLineId;
  final Map<int, LineLogoutStatus> logoutStatus;
  final RegistryEvent? lastEvent;

  RegistryActive copyWith({
    Map<int, RollWorkerSession>? sessions,
    int? activeShiftLineId,
    Map<int, LineLogoutStatus>? logoutStatus,
    RegistryEvent? lastEvent,
    bool clearLastEvent = false,
  }) {
    return RegistryActive(
      sessions: sessions ?? this.sessions,
      activeShiftLineId: activeShiftLineId ?? this.activeShiftLineId,
      logoutStatus: logoutStatus ?? this.logoutStatus,
      lastEvent: clearLastEvent ? null : (lastEvent ?? this.lastEvent),
    );
  }
}

/// Result of a logoutAll call. Surfaces in the post-action confirm dialog.
@immutable
class LogoutAllResult {
  const LogoutAllResult({required this.succeeded, required this.failed});
  final Set<int> succeeded;
  final Set<int> failed;
  bool get hasFailures => failed.isNotEmpty;
}
