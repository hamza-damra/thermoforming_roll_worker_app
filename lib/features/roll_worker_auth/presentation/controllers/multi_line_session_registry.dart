import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/storage/session_index_storage.dart';
import '../../../../core/storage/storage_providers.dart';
import '../../../sessions_me/data/sessions_me_providers.dart';
import '../../../sessions_me/domain/sessions_me_repository.dart';
import '../../data/roll_worker_auth_providers.dart';
import '../../domain/entities/roll_worker_session.dart';
import '../../domain/roll_worker_auth_repository.dart';
import 'multi_line_session_registry_state.dart';

/// Source of truth for "what shift-lines am I logged into right now."
///
/// Holds a `Map<int, RollWorkerSession>` keyed by `shiftLineId` plus a
/// pointer to the currently-active line for the multi-line home shell.
/// Replaces the per-line `RollWorkerAuthController` family.
class MultiLineSessionRegistry
    extends Notifier<MultiLineSessionRegistryState> {
  @override
  MultiLineSessionRegistryState build() => const RegistryRestoring();

  RollWorkerAuthRepository get _repo =>
      ref.read(rollWorkerAuthRepositoryProvider);

  SessionIndexStorage get _index => ref.read(sessionIndexStorageProvider);

  /// Cold-start / app-resume: read the persisted index, fan out
  /// `/current` calls, drop ids whose response is one of the cascade
  /// codes, retain ids that hit transport-level failures.
  ///
  /// On cold start the controller's initial state is [RegistryRestoring],
  /// so the home shell shows the full-screen checking spinner exactly once.
  /// On app-resume the state is typically [RegistryActive]; we **must not**
  /// route through [RegistryRestoring] in that case — doing so would
  /// collapse the loaded home screen to a spinner for the duration of the
  /// `/current` fan-out (this was one of the four root causes of the
  /// 2–3 blink flicker on resume).
  Future<void> restoreFromStorage() async {
    final Set<int> ids = await _index.readIds();
    if (ids.isEmpty) {
      state = const RegistryEmpty();
      return;
    }
    if (state is! RegistryActive) {
      state = const RegistryRestoring();
    }

    final List<int> orderedIds = ids.toList(growable: false);
    final List<RollWorkerAuthResult> results = await Future.wait(
      orderedIds.map(_repo.getCurrentSession),
    );

    final Map<int, RollWorkerSession> survivors = <int, RollWorkerSession>{};
    final Set<int> retainedOnTransientFailure = <int>{};

    for (int i = 0; i < orderedIds.length; i++) {
      final int id = orderedIds[i];
      final RollWorkerAuthResult result = results[i];
      switch (result) {
        case RollWorkerAuthSuccess(:final session):
          if (session.isActive) {
            survivors[id] = session;
          } else {
            await _repo.clearStoredToken(id);
          }
        case RollWorkerAuthFailure(:final failure):
          if (_isCascadeFailure(failure)) {
            await _repo.clearStoredToken(id);
          } else {
            // Transport / server / unknown: keep the id so the next
            // resume can retry.
            retainedOnTransientFailure.add(id);
          }
      }
    }

    final Set<int> keptIds = <int>{
      ...survivors.keys,
      ...retainedOnTransientFailure,
    };
    await _index.writeIds(keptIds);

    if (survivors.isEmpty) {
      state = const RegistryEmpty();
      return;
    }
    // Preserve the currently-active pointer across resume so the PageView
    // doesn't jump back to the first tab on every foreground. Falls back
    // to the first survivor only when the previous active line is gone.
    final MultiLineSessionRegistryState current = state;
    final int? previousActive =
        current is RegistryActive ? current.activeShiftLineId : null;
    final int nextActive = previousActive != null && survivors.containsKey(previousActive)
        ? previousActive
        : survivors.keys.first;
    state = RegistryActive(
      sessions: survivors,
      activeShiftLineId: nextActive,
      logoutStatus: <int, LineLogoutStatus>{
        for (final int id in survivors.keys) id: LineLogoutStatus.idle,
      },
    );
  }

  /// Called by `BatchAuthController` on a successful batch-start. Merges
  /// the new sessions over any existing ones (same-worker collision returns
  /// a fresh token — always overwrite) and seeds the active pointer when
  /// the registry was previously empty.
  Future<void> onBatchSuccess(Map<int, RollWorkerSession> incoming) async {
    final Map<int, RollWorkerSession> merged;
    final Map<int, LineLogoutStatus> mergedStatus;
    final int active;

    final MultiLineSessionRegistryState current = state;
    if (current is RegistryActive) {
      merged = <int, RollWorkerSession>{...current.sessions, ...incoming};
      mergedStatus = <int, LineLogoutStatus>{
        ...current.logoutStatus,
        for (final int id in incoming.keys) id: LineLogoutStatus.idle,
      };
      active = current.activeShiftLineId;
    } else {
      merged = Map<int, RollWorkerSession>.from(incoming);
      mergedStatus = <int, LineLogoutStatus>{
        for (final int id in incoming.keys) id: LineLogoutStatus.idle,
      };
      active = incoming.keys.first;
    }

    await _index.writeIds(merged.keys.toSet());

    state = RegistryActive(
      sessions: merged,
      activeShiftLineId: active,
      logoutStatus: mergedStatus,
      lastEvent: BatchAdded(incoming.keys.toSet()),
    );
  }

  /// Pointer move only — no I/O. Tap a chip to switch the rendered line.
  void setActive(int shiftLineId) {
    final MultiLineSessionRegistryState current = state;
    if (current is! RegistryActive) return;
    if (!current.sessions.containsKey(shiftLineId)) return;
    state = current.copyWith(
      activeShiftLineId: shiftLineId,
      clearLastEvent: true,
    );
  }

  /// Per-line deliberate logout. Calls the existing repo logout (which
  /// clears the per-line token), drops the id, reassigns active.
  Future<void> logout(int shiftLineId) async {
    final MultiLineSessionRegistryState current = state;
    if (current is! RegistryActive) return;
    if (!current.sessions.containsKey(shiftLineId)) return;

    final Map<int, LineLogoutStatus> startingStatus =
        <int, LineLogoutStatus>{
          ...current.logoutStatus,
          shiftLineId: LineLogoutStatus.loggingOut,
        };
    state = current.copyWith(
      logoutStatus: startingStatus,
      clearLastEvent: true,
    );

    bool success = true;
    try {
      await _repo.logout(shiftLineId);
    } catch (_) {
      success = false;
    }

    final MultiLineSessionRegistryState afterCall = state;
    if (afterCall is! RegistryActive) return;

    if (!success) {
      state = afterCall.copyWith(
        logoutStatus: <int, LineLogoutStatus>{
          ...afterCall.logoutStatus,
          shiftLineId: LineLogoutStatus.failedRetryable,
        },
      );
      return;
    }

    final Map<int, RollWorkerSession> remaining =
        Map<int, RollWorkerSession>.from(afterCall.sessions)
          ..remove(shiftLineId);
    final Map<int, LineLogoutStatus> remainingStatus =
        Map<int, LineLogoutStatus>.from(afterCall.logoutStatus)
          ..remove(shiftLineId);
    await _index.writeIds(remaining.keys.toSet());

    if (remaining.isEmpty) {
      state = RegistryEmpty(lastEvent: DeliberateLogout(shiftLineId));
      return;
    }
    final int newActive = afterCall.activeShiftLineId == shiftLineId
        ? remaining.keys.first
        : afterCall.activeShiftLineId;
    state = RegistryActive(
      sessions: remaining,
      activeShiftLineId: newActive,
      logoutStatus: remainingStatus,
      lastEvent: DeliberateLogout(shiftLineId),
    );
  }

  /// Logs out every active line in ONE backend round-trip via
  /// `POST /sessions/leave-all` (handoff §2.3 / §5.4). The repo wipes every
  /// per-line token from secure storage and clears the session index on
  /// success — this controller just collapses the registry to
  /// [RegistryEmpty]. The endpoint is idempotent (returns 204 even when
  /// zero sessions were active) so a parallel cascade can't make this fail.
  ///
  /// On a transport / server failure the registry is left intact with
  /// every line marked `failedRetryable` so the user can retry from the
  /// menu — matches the prior per-line fan-out semantics.
  Future<LogoutAllResult> logoutAll() async {
    final MultiLineSessionRegistryState current = state;
    if (current is! RegistryActive) {
      return const LogoutAllResult(
        succeeded: <int>{},
        failed: <int>{},
      );
    }
    final List<int> targets = current.sessions.keys.toList(growable: false);

    state = current.copyWith(
      logoutStatus: <int, LineLogoutStatus>{
        for (final int id in targets) id: LineLogoutStatus.loggingOut,
      },
      clearLastEvent: true,
    );

    final SessionsMeRepository sessionsMe = ref.read(
      sessionsMeRepositoryProvider,
    );
    final LeaveAllResult result = await sessionsMe.leaveAll();

    switch (result) {
      case LeaveAllSuccess():
        // Server-side AND local tokens / index are now empty. Drop every
        // line in one transition; no per-line "succeeded/failed" split.
        state = RegistryEmpty(
          lastEvent: DeliberateLogout(current.activeShiftLineId),
        );
        return LogoutAllResult(
          succeeded: targets.toSet(),
          failed: const <int>{},
        );
      case LeaveAllFailure():
        // Everything is still alive on the server. Restore the registry
        // and mark every line failed-retryable.
        final MultiLineSessionRegistryState afterCall = state;
        if (afterCall is RegistryActive) {
          state = afterCall.copyWith(
            logoutStatus: <int, LineLogoutStatus>{
              for (final int id in targets) id: LineLogoutStatus.failedRetryable,
            },
            lastEvent: PartialLogoutAll(failed: targets.toSet()),
          );
        }
        return LogoutAllResult(
          succeeded: const <int>{},
          failed: targets.toSet(),
        );
    }
  }

  /// Called by feature controllers (scan, previous-roll, label-reprint)
  /// when a mutating endpoint returns `ROLL_WORKER_SESSION_REQUIRED` /
  /// `THERMOFORMING_SHIFT_LINE_NOT_*`. Drops the local token + the id; the
  /// bootstrap snackbar fires only when the lost line was the active one
  /// or the registry just became empty.
  Future<void> notifySessionLost(int shiftLineId) async {
    await _repo.clearStoredToken(shiftLineId);

    final MultiLineSessionRegistryState current = state;
    if (current is! RegistryActive) return;
    if (!current.sessions.containsKey(shiftLineId)) return;

    final Map<int, RollWorkerSession> remaining =
        Map<int, RollWorkerSession>.from(current.sessions)
          ..remove(shiftLineId);
    final Map<int, LineLogoutStatus> remainingStatus =
        Map<int, LineLogoutStatus>.from(current.logoutStatus)
          ..remove(shiftLineId);
    await _index.writeIds(remaining.keys.toSet());

    if (remaining.isEmpty) {
      state = RegistryEmpty(lastEvent: LineLost(shiftLineId));
      return;
    }
    final int newActive = current.activeShiftLineId == shiftLineId
        ? remaining.keys.first
        : current.activeShiftLineId;
    state = RegistryActive(
      sessions: remaining,
      activeShiftLineId: newActive,
      logoutStatus: remainingStatus,
      lastEvent: LineLost(shiftLineId),
    );
  }

  /// Clears [RegistryActive.lastEvent] / [RegistryEmpty.lastEvent] after
  /// the bootstrap listener has consumed it.
  void clearLastEvent() {
    final MultiLineSessionRegistryState current = state;
    if (current is RegistryActive && current.lastEvent != null) {
      state = current.copyWith(clearLastEvent: true);
    } else if (current is RegistryEmpty && current.lastEvent != null) {
      state = const RegistryEmpty();
    }
  }

  Set<int> get activeShiftLineIds {
    final MultiLineSessionRegistryState current = state;
    return current is RegistryActive ? current.sessions.keys.toSet() : <int>{};
  }

  bool _isCascadeFailure(AppFailure failure) {
    if (failure is! BusinessFailure) return false;
    return failure.code == ErrorCode.rollWorkerSessionRequired ||
        failure.code == ErrorCode.thermoformingShiftLineNotFound ||
        failure.code == ErrorCode.thermoformingShiftLineNotActive;
  }
}

final NotifierProvider<MultiLineSessionRegistry, MultiLineSessionRegistryState>
multiLineSessionRegistryProvider =
    NotifierProvider<MultiLineSessionRegistry, MultiLineSessionRegistryState>(
      MultiLineSessionRegistry.new,
    );
