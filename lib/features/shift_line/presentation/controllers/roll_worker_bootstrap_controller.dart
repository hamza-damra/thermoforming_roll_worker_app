import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/refresh_log.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../../../sessions_me/presentation/controllers/sse_lifecycle_controller.dart';
import '../../data/roll_worker_bootstrap_providers.dart';
import '../../domain/entities/roll_worker_bootstrap_line.dart';
import '../../domain/entities/roll_worker_lines_event.dart';
import '../../domain/roll_worker_bootstrap_repository.dart';
import 'roll_worker_bootstrap_poll_config.dart';
import 'roll_worker_bootstrap_state.dart';
import 'selected_shift_line_provider.dart';

/// Drives the pre-login bootstrap picker.
///
/// Architecture (realtime + line-management handoff §4):
///   - The REST `/bootstrap` response is **authoritative**. The picker
///     re-renders from it on every refresh.
///   - The global `/events` SSE channel (owned by [SseLifecycleController])
///     is **only a refresh trigger** — no SSE payload is trusted as
///     business state. This controller registers a listener with the
///     lifecycle controller; on any frame it debounces (~250 ms) and
///     silently refetches `/bootstrap`.
///   - On SSE (re)connect and on app-resume it refetches `/bootstrap`
///     immediately (the in-memory broker has no replay).
///   - A `/bootstrap` poll is a **fallback only** — runs at 2 s while the
///     SSE link is down, and is fully OFF while SSE is connected. Never
///     the primary update mechanism.
///   - Background refreshes (SSE / poll / resume) update rows in place —
///     they never emit [RollWorkerBootstrapLoading], so no full-screen
///     loader flashes. Only the initial load and pull-to-refresh show
///     the loader.
///   - The poll + frame consumption are suspended once the worker logs in
///     (`RegistryActive`) and resumed if they return to the picker. The
///     global SSE subscription itself stays open across that transition
///     because it's owned by the lifecycle controller, not this one.
class RollWorkerBootstrapController extends Notifier<RollWorkerBootstrapState> {
  late RollWorkerBootstrapPollConfig _config;

  /// Fallback REST poll. Runs ONLY while the picker is the active surface
  /// AND the SSE link is reported disconnected.
  Timer? _pollTimer;
  Duration? _currentInterval;

  /// Incremented every time a *new* poll timer is created. Tests assert this
  /// does not advance on a no-op cadence recompute (no duplicate timers).
  int _pollTimerGeneration = 0;

  /// Coalesces a burst of SSE frames into a single debounced refetch.
  Timer? _debounceTimer;

  /// Whether the SSE link is currently connected — decides whether the
  /// fallback poll runs.
  bool _sseConnected = false;

  /// Monotonic sequence stamped on every [refresh]. A refresh whose stamp
  /// has been superseded by a newer one when its `/bootstrap` response
  /// resolves is discarded, so a slow/out-of-order REST response can never
  /// apply a stale snapshot over a fresher one. This also makes overlapping
  /// refreshes (SSE event + poll + resume) safe.
  int _refreshSeq = 0;

  /// Bound to [SseLifecycleController] via [addPickerListener] in [build] —
  /// stored so [_detachFromSseLifecycle] can remove it cleanly.
  late final void Function(RollWorkerLinesStreamItem) _onSseItemBound;

  @override
  RollWorkerBootstrapState build() {
    _config = ref.read(rollWorkerBootstrapPollConfigProvider);
    _onSseItemBound = _onSseItem;
    ref.onDispose(() {
      _stopPolling();
      _cancelDebounce();
      _detachFromSseLifecycle();
    });
    // Suspend the poll + frame consumption once the worker is logged in
    // (the home screen owns refresh from there); resume + re-fetch if they
    // return to the picker. The global SSE subscription is owned by
    // [SseLifecycleController] and stays open across these transitions.
    ref.listen<MultiLineSessionRegistryState>(
      multiLineSessionRegistryProvider,
      (_, next) => _syncForRegistry(next),
    );
    // Attach to the global SSE lifecycle on a microtask — Riverpod
    // forbids mutating another provider (addPickerListener / start)
    // synchronously inside `build`.
    Future<void>.microtask(_attachToSseLifecycle);
    Future<void>.microtask(() => refresh(trigger: 'initial-build'));
    return const RollWorkerBootstrapInitial();
  }

  RollWorkerBootstrapRepository get _repo =>
      ref.read(rollWorkerBootstrapRepositoryProvider);

  /// Re-fetches the `/bootstrap` rows.
  ///
  /// [trigger] is diagnostic only — it labels the refresh source in the
  /// debug log (initial-build / sse-connected / sse-event / poll /
  /// app-resume / manual / registry-emptied).
  ///
  /// When [background] is true (SSE event / reconnect / poll / app-resume)
  /// the controller does NOT emit a loading state — it updates rows in
  /// place, and a transient failure keeps the last good list visible.
  Future<void> refresh({
    String trigger = 'manual',
    bool background = false,
  }) async {
    final int seq = ++_refreshSeq;
    final List<RollWorkerBootstrapLine> previous = _previousLines;
    if (!background) {
      state = RollWorkerBootstrapLoading(previous: previous);
    }
    refreshLog(
      'picker refresh triggered (reason=$trigger, background=$background)',
    );

    final RollWorkerBootstrapResult result = await _repo.fetch();
    // A newer refresh was issued while this one was in flight — discard
    // this (now stale) response so it cannot overwrite the fresher one.
    if (seq != _refreshSeq) {
      refreshLog('picker refresh #$seq superseded by #$_refreshSeq — discarded');
      return;
    }
    switch (result) {
      case RollWorkerBootstrapSuccess(:final lines):
        state = RollWorkerBootstrapLoaded(lines);
        refreshLog(
          'picker refresh result: ${lines.length} machine(s) '
          '[${lines.map((l) => l.lineCode).join(', ')}]',
        );
        _revalidateSelection(lines);
      case RollWorkerBootstrapFailure(:final failure):
        if (background && state is RollWorkerBootstrapLoaded) {
          // A background refresh must never disrupt a working list — keep
          // the last good rows; the next poll / event recovers.
          refreshLog(
            'picker background refresh failed (keeping rows): $failure',
          );
        } else {
          state = RollWorkerBootstrapFailureState(
            failure: failure,
            previous: previous,
          );
          refreshLog('picker refresh failed: $failure');
        }
    }
    _recomputePollCadence();
  }

  List<RollWorkerBootstrapLine> get _previousLines {
    return switch (state) {
      RollWorkerBootstrapLoaded(:final lines) => lines,
      RollWorkerBootstrapLoading(:final previous) => previous,
      RollWorkerBootstrapFailureState(:final previous) => previous,
      RollWorkerBootstrapInitial() => const <RollWorkerBootstrapLine>[],
    };
  }

  /// Drops any picker-stage selections whose shift-line no longer appears in
  /// the freshly-fetched rows (or has gone non-selectable). Only selectable
  /// rows carry a non-null `shiftLineId`, so the selection stays valid.
  void _revalidateSelection(List<RollWorkerBootstrapLine> lines) {
    final Set<int> selected = ref.read(pickerShiftLineSelectionProvider);
    if (selected.isEmpty) return;
    final Set<int> stillSelectable = <int>{
      for (final RollWorkerBootstrapLine line in lines)
        if (line.selectable && line.shiftLineId != null) line.shiftLineId!,
    };
    final Set<int> survivors = selected.intersection(stillSelectable);
    if (survivors.length == selected.length) return;
    ref.read(pickerShiftLineSelectionProvider.notifier).replaceWith(survivors);
  }

  // ─── SSE lifecycle frame consumption ──────────────────────────────────

  void _attachToSseLifecycle() {
    final SseLifecycleController lifecycle = ref.read(
      sseLifecycleControllerProvider.notifier,
    );
    lifecycle.addPickerListener(_onSseItemBound);
    lifecycle.start();
  }

  void _detachFromSseLifecycle() {
    // During provider-container teardown the lifecycle controller may
    // already be disposed; swallow the read failure so dispose stays
    // exception-safe.
    try {
      ref
          .read(sseLifecycleControllerProvider.notifier)
          .removePickerListener(_onSseItemBound);
    } catch (_) {
      // Container/provider was already torn down — nothing to detach.
    }
  }

  void _onSseItem(RollWorkerLinesStreamItem item) {
    // Ignore frames once the worker is logged in — the home shell owns
    // refresh and the picker is off-screen.
    final MultiLineSessionRegistryState registry = ref.read(
      multiLineSessionRegistryProvider,
    );
    if (registry is RegistryActive) return;

    switch (item) {
      case PickerSseConnected():
        _sseConnected = true;
        refreshLog('picker SSE connected → immediate bootstrap refresh');
        unawaited(refresh(trigger: 'sse-connected', background: true));
      case PickerSseReconnected():
        _sseConnected = true;
        refreshLog('picker SSE reconnected → immediate bootstrap refresh');
        unawaited(refresh(trigger: 'sse-connected', background: true));
      case PickerSseTransportError(:final error):
        _sseConnected = false;
        refreshLog('picker SSE transport error → reconnecting: $error');
        _recomputePollCadence();
      case PickerSseRefreshTriggered():
        refreshLog('picker SSE event → debounced bootstrap refresh');
        _scheduleDebouncedRefresh();
    }
  }

  void _scheduleDebouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_config.eventDebounce, () {
      _debounceTimer = null;
      unawaited(refresh(trigger: 'sse-event', background: true));
    });
  }

  void _cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  // ─── Registry sync ─────────────────────────────────────────────────────

  void _syncForRegistry(MultiLineSessionRegistryState next) {
    switch (next) {
      case RegistryActive():
        // Worker is logged in — the per-line home screen owns refresh now.
        // The global SSE subscription stays open (owned by
        // [SseLifecycleController]); we only stop *acting* on its frames.
        refreshLog('registry active → picker poll + frame consumption paused');
        _stopPolling();
        _cancelDebounce();
      case RegistryEmpty():
        // Back on the picker (deliberate logout / cascade) — re-fetch
        // immediately; [_recomputePollCadence] resumes the fallback poll
        // iff SSE is currently down.
        refreshLog('registry emptied → picker re-fetch');
        unawaited(refresh(trigger: 'registry-emptied', background: true));
      case RegistryRestoring():
        break;
    }
  }

  // ─── Fallback poll (handoff §4: NO poll while SSE up) ─────────────────

  /// (Re)starts the fallback poll ONLY when the picker is active and SSE
  /// is disconnected. No-op when the desired cadence is already running
  /// (keeps a single timer alive — no duplicate timers).
  void _recomputePollCadence() {
    final MultiLineSessionRegistryState registry = ref.read(
      multiLineSessionRegistryProvider,
    );
    if (registry is RegistryActive) {
      _stopPolling();
      return;
    }
    if (_sseConnected) {
      _stopPolling();
      return;
    }
    final Duration desired = _config.safetyNetInterval;
    if (_pollTimer != null && _currentInterval == desired) return;
    _pollTimer?.cancel();
    _currentInterval = desired;
    _pollTimerGeneration++;
    _pollTimer = Timer.periodic(
      desired,
      (_) => refresh(trigger: 'poll', background: true),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _currentInterval = null;
  }

  // ─── Test hooks ────────────────────────────────────────────────────────

  /// Cadence the running poll timer was created with, or `null` when no
  /// timer is active. Exposed for cadence-tier assertions.
  @visibleForTesting
  Duration? get currentPollInterval => _currentInterval;

  /// Number of distinct poll timers created over this controller's life.
  /// A no-op cadence recompute must not advance it (no duplicate timers).
  @visibleForTesting
  int get pollTimerGeneration => _pollTimerGeneration;

  /// Whether the SSE link is currently reported as connected.
  @visibleForTesting
  bool get sseConnected => _sseConnected;
}

final rollWorkerBootstrapControllerProvider =
    NotifierProvider<RollWorkerBootstrapController, RollWorkerBootstrapState>(
      RollWorkerBootstrapController.new,
    );
