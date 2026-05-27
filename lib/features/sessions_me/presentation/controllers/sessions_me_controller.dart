import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/refresh_log.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../../../core/storage/storage_providers.dart';
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
/// Cascade detection: on every successful response the controller diffs
/// `me.shiftLineIds` against [MultiLineSessionRegistry.activeShiftLineIds].
/// Any id present locally but missing remotely was cascaded (operator
/// ended shift, takeover replaced this worker, etc.). For each such id
/// the controller deletes the token and calls
/// [MultiLineSessionRegistry.notifySessionLost], which collapses the
/// registry to [RegistryEmpty] when no lines remain.
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

  SecureTokenStorage get _tokenStorage =>
      ref.read(secureTokenStorageProvider);

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
    refreshLog('sessions-me failed: $failure');
    // 401 with all tokens stale → collapse to picker via the registry.
    if (failure is BusinessFailure &&
        failure.code == ErrorCode.rollWorkerSessionRequired) {
      await _evictAllTokensAndNotify();
      return;
    }
    // Background failure on top of a working snapshot — keep the snapshot.
    if (background && previous != null) {
      state = SessionsMeLoaded(
        me: previous,
        fetchedAt: DateTime.now(),
      );
      return;
    }
    state = SessionsMeError(failure: failure, previous: previous);
  }

  /// Walks `/sessions/me`'s `lines` and drops any registry id NOT in it
  /// (handoff §3.4 — operator ended shift / takeover replaced us).
  Future<void> _reconcileRegistry(RollWorkerMe me) async {
    final MultiLineSessionRegistryState registry = ref.read(
      multiLineSessionRegistryProvider,
    );
    if (registry is! RegistryActive) return;
    final Set<int> remote = me.shiftLineIds;
    final Set<int> local = registry.sessions.keys.toSet();
    final Set<int> cascaded = local.difference(remote);
    if (cascaded.isEmpty) return;
    refreshLog(
      'sessions-me cascade detected → dropping ${cascaded.length} line(s) '
      '[${cascaded.join(', ')}]',
    );
    for (final int id in cascaded) {
      await ref
          .read(multiLineSessionRegistryProvider.notifier)
          .notifySessionLost(id);
    }
  }

  Future<void> _evictAllTokensAndNotify() async {
    final MultiLineSessionRegistryState registry = ref.read(
      multiLineSessionRegistryProvider,
    );
    if (registry is! RegistryActive) {
      state = const SessionsMeIdle();
      return;
    }
    refreshLog('sessions-me 401 → evicting all tokens, routing to picker');
    final Set<int> ids = registry.sessions.keys.toSet();
    await _tokenStorage.clearAllSessionTokens(ids);
    for (final int id in ids) {
      await ref
          .read(multiLineSessionRegistryProvider.notifier)
          .notifySessionLost(id);
    }
    state = const SessionsMeIdle();
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
