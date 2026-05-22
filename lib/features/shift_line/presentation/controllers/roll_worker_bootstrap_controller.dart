import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/refresh_log.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../../data/roll_worker_bootstrap_providers.dart';
import '../../data/roll_worker_lines_sse_providers.dart';
import '../../domain/entities/roll_worker_bootstrap_line.dart';
import '../../domain/entities/roll_worker_lines_event.dart';
import '../../domain/roll_worker_bootstrap_repository.dart';
import 'roll_worker_bootstrap_poll_config.dart';
import 'roll_worker_bootstrap_state.dart';
import 'selected_shift_line_provider.dart';

/// Drives the pre-login bootstrap picker.
///
/// Architecture (Line State Refresh handoff — mirrors the Pallet Worker app):
///   - The REST `/bootstrap` response is **authoritative**. The picker
///     re-renders from it on every refresh.
///   - The global `/events` SSE channel is **only a refresh trigger** — no
///     SSE payload is trusted as business state. On any frame the controller
///     debounces (~250 ms) and silently refetches `/bootstrap`.
///   - On SSE (re)connect and on app-resume it refetches `/bootstrap`
///     immediately (the in-memory broker has no replay, so a gap may have
///     hidden an event).
///   - A slow `/bootstrap` poll is a **safety net only** — ~60 s while SSE
///     is connected, ~30 s while it is down. There is no fast visible poll.
///   - Background refreshes (SSE / poll / resume) update rows in place — they
///     never emit [RollWorkerBootstrapLoading], so no full-screen loader
///     flashes. Only the initial load and pull-to-refresh show the loader.
///   - The poll + SSE subscription are suspended once the worker logs in
///     (`RegistryActive`) and resumed if they return to the picker.
class RollWorkerBootstrapController extends Notifier<RollWorkerBootstrapState> {
  late RollWorkerBootstrapPollConfig _config;

  /// Slow safety-net poll. Exactly one timer runs while the picker is the
  /// active surface. [_currentInterval] records the cadence the running
  /// timer was created with so [_recomputePollCadence] can skip a no-op
  /// restart when the desired cadence is unchanged.
  Timer? _pollTimer;
  Duration? _currentInterval;

  /// Incremented every time a *new* poll timer is created. Tests assert this
  /// does not advance on a no-op cadence recompute (no duplicate timers).
  int _pollTimerGeneration = 0;

  /// Coalesces a burst of SSE frames into a single debounced refetch.
  Timer? _debounceTimer;

  /// Live subscription to the pre-login `/events` SSE channel.
  StreamSubscription<RollWorkerLinesStreamItem>? _sseSubscription;

  /// Whether the SSE link is currently connected — selects the slow vs
  /// safety-net poll cadence tier.
  bool _sseConnected = false;

  /// Monotonic sequence stamped on every [refresh]. A refresh whose stamp
  /// has been superseded by a newer one when its `/bootstrap` response
  /// resolves is discarded, so a slow/out-of-order REST response can never
  /// apply a stale snapshot over a fresher one (handoff §6). This also
  /// makes overlapping refreshes (SSE event + poll + resume) safe.
  int _refreshSeq = 0;

  @override
  RollWorkerBootstrapState build() {
    _config = ref.read(rollWorkerBootstrapPollConfigProvider);
    ref.onDispose(() {
      _stopPolling();
      _cancelDebounce();
      _stopSse();
    });
    // Suspend the poll + SSE once the worker is logged in (the home screen
    // owns refresh from there); resume + re-fetch if they return to the
    // picker.
    ref.listen<MultiLineSessionRegistryState>(
      multiLineSessionRegistryProvider,
      (_, next) => _syncForRegistry(next),
    );
    Future<void>.microtask(() => refresh(trigger: 'initial-build'));
    _openSse();
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

  // ─── Pre-login SSE channel (handoff §2) ────────────────────────────────

  void _openSse() {
    _sseSubscription?.cancel();
    _sseConnected = false;
    _sseSubscription = ref
        .read(rollWorkerLinesSseClientProvider)
        .subscribe()
        .listen(_onSseItem);
  }

  void _stopSse() {
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _sseConnected = false;
  }

  void _onSseItem(RollWorkerLinesStreamItem item) {
    switch (item) {
      case PickerSseConnected():
        _sseConnected = true;
        refreshLog('picker SSE connected → immediate bootstrap refresh');
        // Converge on a known snapshot — a gap may have hidden an event.
        unawaited(refresh(trigger: 'sse-connected', background: true));
      case PickerSseReconnected():
        _sseConnected = true;
        refreshLog('picker SSE reconnected → immediate bootstrap refresh');
        unawaited(refresh(trigger: 'sse-connected', background: true));
      case PickerSseTransportError(:final error):
        _sseConnected = false;
        refreshLog('picker SSE transport error → reconnecting: $error');
        // Move the safety-net poll to the faster (disconnected) tier.
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
        refreshLog('registry active → picker poll + SSE suspended');
        _stopPolling();
        _cancelDebounce();
        _stopSse();
      case RegistryEmpty():
        // Back on the picker (deliberate logout / cascade) — re-open SSE
        // and re-fetch; `refresh()` resumes the safety-net poll.
        refreshLog('registry emptied → picker re-open SSE + re-fetch');
        if (_sseSubscription == null) _openSse();
        unawaited(refresh(trigger: 'registry-emptied', background: true));
      case RegistryRestoring():
        break;
    }
  }

  // ─── Slow safety-net poll (handoff §4/§5) ──────────────────────────────

  /// (Re)starts the safety-net poll at the cadence implied by SSE link
  /// health. A no-op when the desired cadence is already running — this is
  /// what keeps a single timer alive (no duplicate timers). Suspended while
  /// logged in.
  void _recomputePollCadence() {
    final MultiLineSessionRegistryState registry = ref.read(
      multiLineSessionRegistryProvider,
    );
    if (registry is RegistryActive) {
      _stopPolling();
      return;
    }
    final Duration desired = _desiredInterval();
    if (_pollTimer != null && _currentInterval == desired) return;
    _pollTimer?.cancel();
    _currentInterval = desired;
    _pollTimerGeneration++;
    _pollTimer = Timer.periodic(
      desired,
      (_) => refresh(trigger: 'poll', background: true),
    );
  }

  /// Slow while SSE is connected (SSE is then the primary update path);
  /// faster while it is down (the poll is the only recovery path).
  Duration _desiredInterval() => _sseConnected
      ? _config.safetyNetSlowInterval
      : _config.safetyNetInterval;

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
