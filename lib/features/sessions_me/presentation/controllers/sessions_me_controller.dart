import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/refresh_log.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../../data/sessions_me_providers.dart';
import '../../domain/entities/roll_worker_me.dart';
import '../../domain/sessions_me_repository.dart';
import 'sessions_me_poll_config.dart';
import 'sessions_me_state.dart';

/// Single source of truth for the worker's post-login state across all
/// active lines. Wraps `GET /sessions/me`.
///
/// SSE lifecycle is OWNED by [SseLifecycleController]; this controller is
/// fed status + refresh-trigger callbacks via [notifySseConnected],
/// [notifySseDisconnected], and [notifyRefreshTrigger]. This keeps the
/// global SSE subscription single-owner and avoids resubscribing per
/// controller.
///
/// Polling contract (handoff §4):
///   - SSE connected → fallback poll OFF.
///   - SSE disconnected → fallback poll at 2 s.
///   - On reconnect → one immediate catch-up refresh, fallback poll OFF.
///
/// Merge-based reconciliation (handoff §6). `/sessions/me` is worker-scoped
/// and `start-batch` is additive — `start-batch [81]` while `82` is active
/// leaves BOTH lines active, and a single `/sessions/me` returns every line
/// the worker owns. On every SUCCESSFUL response the controller MERGES the
/// worker's active lines into the registry and drops a local line ONLY once
/// that exact line has been confirmed active by a prior `/sessions/me` and
/// is now absent (handoff §7). A line that `start-batch` just created can be
/// momentarily missing from `/sessions/me` due to read-after-write lag
/// (handoff §6.5 "transiently omitted"); dropping it then is the production
/// multi-line login-loop bug, so an as-yet-unconfirmed line is never
/// cascade-dropped. A non-2xx `/sessions/me` drops NOTHING (handoff §6.4):
/// the registry is preserved and recovery is left to the next SSE / poll
/// refresh or a per-line re-auth.
class SessionsMeController extends Notifier<SessionsMeState> {
  late SessionsMePollConfig _config;

  /// Monotonic refresh sequence — a slow response whose seq is older than
  /// `_refreshSeq` when it resolves is discarded. Prevents an out-of-order
  /// REST response from overwriting a fresher one (handoff edge case).
  int _refreshSeq = 0;

  /// Coalesces a burst of SSE frames into a single REST refetch.
  Timer? _debounceTimer;

  /// Fixed-cadence fallback poll. Runs ONLY while `_sseConnected = false`
  /// AND the worker has at least one active session.
  Timer? _fallbackPollTimer;

  /// True iff the SSE link is currently reported as connected. Drives the
  /// fallback poll on/off.
  bool _sseConnected = false;

  /// Shift-line ids that at least one SUCCESSFUL `/sessions/me` has reported
  /// ACTIVE for this worker. A line becomes reconciliation-droppable only
  /// after it appears here — this is the guard that stops a freshly
  /// `start-batch`-created line from being cascade-dropped by a stale /
  /// lagging `/sessions/me` that has not yet caught up to the new session
  /// (handoff §6.5 "transiently omitted"). Ids are forgotten as they leave
  /// the registry; the set resets to empty on controller rebuild, after
  /// which the next refresh re-confirms every still-active line — so it can
  /// only ever err toward KEEPING a line, never toward dropping one.
  final Set<int> _confirmedLineIds = <int>{};

  @override
  SessionsMeState build() {
    _config = ref.read(sessionsMePollConfigProvider);
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _stopFallbackPoll();
    });
    // Stop / start the fallback poll as the registry transitions
    // (RegistryEmpty → no poll, RegistryActive → poll iff SSE down).
    ref.listen<MultiLineSessionRegistryState>(
      multiLineSessionRegistryProvider,
      (_, next) => _syncForRegistry(next),
    );
    return const SessionsMeIdle();
  }

  SessionsMeRepository get _repo => ref.read(sessionsMeRepositoryProvider);

  // ─── Public API consumed by SseLifecycleController + UI ─────────────────

  /// Refetch `/sessions/me` and reconcile the registry.
  ///
  /// [trigger] is diagnostic only — labels the source in the refresh log
  /// (initial / sse-event / sse-reconnect / poll / login / manual).
  ///
  /// [background] keeps the previous loaded state visible while the call
  /// is in flight; only the first foreground load shows
  /// [SessionsMeLoading].
  Future<void> refresh({
    String trigger = 'manual',
    bool background = true,
  }) async {
    // Skip when the worker is not (or not yet) authenticated — no token
    // means the request will short-circuit to `rollWorkerSessionRequired`
    // and that just churns the state with a useless error.
    final MultiLineSessionRegistryState registry = ref.read(
      multiLineSessionRegistryProvider,
    );
    if (registry is! RegistryActive) {
      // Make sure we don't keep stale loaded state around if the worker
      // is no longer logged in.
      if (state is! SessionsMeIdle) state = const SessionsMeIdle();
      return;
    }

    final int seq = ++_refreshSeq;
    final RollWorkerMe? previous = _previousMe;

    if (!background) {
      state = SessionsMeLoading(previous: previous);
    }
    // Background refreshes intentionally DO NOT emit an intermediate
    // `isRefreshing: true` state — that double-toggle (true → false on
    // success) used to trigger two PageView rebuilds per refresh and is
    // the second of the four root causes traced in the resume-flicker
    // investigation. `_refreshSeq` already protects against out-of-order
    // responses; no UI surface reads this flag on SessionsMeLoaded today.
    refreshLog('sessions-me refresh #$seq (trigger=$trigger, bg=$background)');

    final SessionsMeResult result = await _repo.fetchMe();

    // A newer refresh superseded this one — discard.
    if (seq != _refreshSeq) {
      refreshLog('sessions-me refresh #$seq superseded by #$_refreshSeq');
      return;
    }

    switch (result) {
      case SessionsMeSuccess(:final me):
        state = SessionsMeLoaded(me: me, fetchedAt: DateTime.now());
        refreshLog(
          'sessions-me ok: ${me.lines.length} line(s) '
          '[${me.lines.map((l) => l.shiftLineId).join(', ')}]',
        );
        unawaited(_reconcileRegistry(me));
      case SessionsMeFailure(:final failure):
        await _onFailure(failure, previous: previous, background: background);
    }
  }

  /// Called by [SseLifecycleController] on every refresh-trigger frame.
  /// Debounces, then refreshes once.
  void notifyRefreshTrigger() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_config.eventDebounce, () {
      _debounceTimer = null;
      unawaited(refresh(trigger: 'sse-event'));
    });
  }

  /// Called by [SseLifecycleController] when the SSE handshake completes
  /// (initial connect or reconnect). Stops the fallback poll and fires
  /// one immediate catch-up refresh (handoff §4 — on reconnect refetch
  /// once to catch up missed frames).
  void notifySseConnected({required bool isReconnect}) {
    _sseConnected = true;
    _stopFallbackPoll();
    refreshLog(
      'sessions-me sse connected (reconnect=$isReconnect) '
      '→ immediate refresh, fallback poll OFF',
    );
    unawaited(
      refresh(trigger: isReconnect ? 'sse-reconnect' : 'sse-connected'),
    );
  }

  /// Called by [SseLifecycleController] on transport error / disconnect.
  /// Starts the 2s fallback poll iff the worker is logged in.
  void notifySseDisconnected() {
    _sseConnected = false;
    _startFallbackPollIfActive();
    refreshLog('sessions-me sse disconnected → fallback poll ON (if active)');
  }

  // ─── Internals ──────────────────────────────────────────────────────────

  void _syncForRegistry(MultiLineSessionRegistryState next) {
    switch (next) {
      case RegistryActive():
        // Just logged in (or restored from storage) — fetch immediately
        // so the home shell has lines to render.
        if (state is SessionsMeIdle) {
          unawaited(refresh(trigger: 'login-or-restore', background: false));
        }
        _startFallbackPollIfActive();
      case RegistryEmpty():
      case RegistryRestoring():
        _stopFallbackPoll();
        if (state is! SessionsMeIdle) state = const SessionsMeIdle();
    }
  }

  Future<void> _onFailure(
    AppFailure failure, {
    required RollWorkerMe? previous,
    required bool background,
  }) async {
    // Handoff §6.4 / §7: a non-2xx `/sessions/me` is NEVER evidence that any
    // line ended. The token we sent may simply have been rotated/replaced —
    // the repo already retried with a DIFFERENT token before surfacing this.
    // So we drop NO line and evict NO token here; the worker stays logged in
    // on every active line and the registry is preserved. Recovery is the
    // next SSE / poll refresh (the fallback poll keeps running while a line
    // is active) or a per-line re-auth. Lines are dropped only by the
    // explicit per-line end signals in handoff §7.
    refreshLog('sessions-me failed (registry preserved, no drop): $failure');
    if (background && previous != null) {
      // Transient background failure on top of a working snapshot — keep it
      // so the home shell does not blank out.
      state = SessionsMeLoaded(me: previous, fetchedAt: DateTime.now());
      return;
    }
    state = SessionsMeError(failure: failure, previous: previous);
  }

  /// Reconciles a SUCCESSFUL, worker-scoped `/sessions/me` against the local
  /// registry (handoff §6.3 / §7).
  ///
  /// `/sessions/me` is authoritative for the resolved worker, so a line we
  /// still hold a token for that the server no longer lists **is** evidence
  /// that exact line ended — but ONLY once we have positively seen that line
  /// in a prior `/sessions/me`. A line that `start-batch` just created
  /// (201 + token) can be momentarily absent because of read-after-write lag;
  /// dropping it then is the multi-line login-loop bug (handoff §6.5). So we
  /// confirm a line the first time the server reports it active, and drop
  /// only confirmed-then-absent lines. Not-yet-confirmed lines are left
  /// intact and reconciled on the next refresh.
  Future<void> _reconcileRegistry(RollWorkerMe me) async {
    final MultiLineSessionRegistryState registry = ref.read(
      multiLineSessionRegistryProvider,
    );
    if (registry is! RegistryActive) return;

    final Set<int> remote = me.shiftLineIds;
    final Set<int> local = registry.sessions.keys.toSet();

    // Positively confirm every held line the worker-scoped response reports
    // ACTIVE, and forget confirmation for ids we no longer hold a token for.
    _confirmedLineIds
      ..addAll(remote.intersection(local))
      ..removeWhere((int id) => !local.contains(id));

    // Drop ONLY lines we have confirmed before AND that this authoritative
    // response now omits. A not-yet-confirmed line (just created, possibly
    // lagging) is never dropped here; a line we don't hold a token for is
    // not ours to manage.
    final Set<int> cascaded = local
        .intersection(_confirmedLineIds)
        .difference(remote);
    if (cascaded.isEmpty) return;

    refreshLog(
      'sessions-me confirmed line(s) ended → dropping ${cascaded.length} '
      'line(s) [${cascaded.join(', ')}]',
    );
    for (final int id in cascaded) {
      _confirmedLineIds.remove(id);
      await ref
          .read(multiLineSessionRegistryProvider.notifier)
          .notifySessionLost(id);
    }
  }

  // ─── Fallback poll ──────────────────────────────────────────────────────

  void _startFallbackPollIfActive() {
    final MultiLineSessionRegistryState registry = ref.read(
      multiLineSessionRegistryProvider,
    );
    if (registry is! RegistryActive) {
      _stopFallbackPoll();
      return;
    }
    if (_sseConnected) {
      _stopFallbackPoll();
      return;
    }
    if (_fallbackPollTimer != null) return; // already running
    _fallbackPollTimer = Timer.periodic(
      _config.fallbackPollInterval,
      (_) => refresh(trigger: 'poll'),
    );
    refreshLog(
      'sessions-me fallback poll started '
      '(${_config.fallbackPollInterval.inMilliseconds}ms)',
    );
  }

  void _stopFallbackPoll() {
    if (_fallbackPollTimer == null) return;
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = null;
    refreshLog('sessions-me fallback poll stopped');
  }

  RollWorkerMe? get _previousMe {
    final SessionsMeState current = state;
    return switch (current) {
      SessionsMeLoaded(:final me) => me,
      SessionsMeLoading(:final previous) => previous,
      SessionsMeError(:final previous) => previous,
      SessionsMeIdle() => null,
    };
  }

  // ─── Test hooks ─────────────────────────────────────────────────────────

  @visibleForTesting
  bool get hasFallbackPollTimer => _fallbackPollTimer != null;

  @visibleForTesting
  bool get sseConnected => _sseConnected;

  @visibleForTesting
  int get refreshSeq => _refreshSeq;
}

final NotifierProvider<SessionsMeController, SessionsMeState>
sessionsMeControllerProvider =
    NotifierProvider<SessionsMeController, SessionsMeState>(
      SessionsMeController.new,
    );
