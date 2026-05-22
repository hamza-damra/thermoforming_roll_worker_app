import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/refresh_log.dart';
import '../../../home/presentation/controllers/shift_line_summary_controller.dart';
import '../../../home/presentation/controllers/shift_line_summary_state.dart';
import '../../../roll_worker_auth/domain/entities/roll_worker_session.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../../data/operator_dashboard_sse_providers.dart';
import '../../domain/entities/operator_dashboard_event.dart';
import 'operator_dashboard_poll_config.dart';
import 'operator_dashboard_sync_state.dart';

/// Bridges the operator-dashboard SSE stream into the shift-line summary
/// controller and drives the adaptive REST refresh for a single shift-line.
///
/// Architecture (Line State Refresh handoff):
///   - SSE is **only a refresh trigger**. The REST shift-line summary is the
///     single source of truth for line lifecycle / operator / takeover /
///     blocked state — none of which is carried on an SSE payload.
///   - On any relevant SSE event the controller schedules a *debounced*
///     REST refresh ([OperatorDashboardPollConfig.eventDebounce]); a burst
///     of frames arriving together collapses into one refetch (§1).
///   - On the SSE `connected` / `reconnected` handshake it refetches REST
///     *immediately* — it does not wait for the next event (§2).
///   - Roll-level deltas that carry a typed payload (product / weight /
///     returned-remaining) are additionally applied as an optimistic
///     overlay for instant feedback; the debounced REST refresh reconciles
///     them. Line-state / takeover / operator events carry no payload and
///     are handled purely through the refresh.
///
/// Adaptive safety-net poll (§4/§5):
///   The broker is in-memory with no `Last-Event-ID` replay, so a periodic
///   summary refetch is the only reliable recovery for a missed event. The
///   cadence adapts to both the SSE link health and the summary state:
///     - fast    — line mid-transition (handover / takeover / waiting /
///                 blocked / unknown lifecycle), or no snapshot yet.
///     - slow    — SSE connected and the line is stable.
///     - medium  — SSE link down / reconnecting.
///
/// Lifecycle (§6):
///   - Exactly one poll timer exists per shift-line at a time.
///   - `start()` is idempotent; `stop()` / logout / `ref.onDispose` tear
///     the subscription, poll timer and debounce timer down.
///   - `onAppPaused()` drops the poll while backgrounded; `onAppResumed()`
///     refreshes immediately and restarts the adaptive poll.
class OperatorDashboardSyncController
    extends FamilyNotifier<OperatorDashboardSyncState, int> {
  late int _shiftLineId;
  late OperatorDashboardPollConfig _config;
  StreamSubscription<OperatorDashboardStreamItem>? _subscription;
  int? _boundPalletizingLineId;
  ProviderSubscription<MultiLineSessionRegistryState>? _registryListener;

  /// Safety-net REST poll. Exactly one timer runs while an SSE subscription
  /// is active and the app is foregrounded. [_currentPollInterval] records
  /// the cadence it was created with so [_recomputeAndApplyCadence] can skip
  /// a no-op restart when the desired cadence is unchanged.
  Timer? _pollTimer;
  Duration? _currentPollInterval;

  /// Coalesces a burst of SSE events into a single debounced REST refresh.
  Timer? _debounceTimer;

  /// `true` while the app is backgrounded — the poll is suspended (§6).
  bool _appPaused = false;

  /// Incremented every time a *new* poll timer is created. Tests assert this
  /// does not advance on a no-op cadence recompute (no duplicate timers).
  int _pollTimerGeneration = 0;

  @override
  OperatorDashboardSyncState build(int arg) {
    _shiftLineId = arg;
    _config = ref.read(operatorDashboardPollConfigProvider);
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      _registryListener?.close();
      _registryListener = null;
      _stopPolling();
      _cancelDebounce();
    });
    // Re-evaluate the poll cadence whenever the summary changes — a takeover
    // appearing, the operator leaving, or a `blocked` flag flipping all move
    // the line between the stable and fast cadence tiers (§5).
    ref.listen<ShiftLineSummaryState>(
      shiftLineSummaryControllerProvider(arg),
      (_, _) => _recomputeAndApplyCadence(),
      fireImmediately: true,
    );
    return const OperatorDashboardSyncState.idle();
  }

  // ─── Subscription lifecycle ────────────────────────────────────────────

  /// Begins consuming SSE events for this shift-line.
  ///
  /// Looks up the palletizing-line id from the active session registry.
  /// When no session is currently registered, transitions to
  /// [OperatorDashboardSyncStatus.unauthenticated] and waits — the caller
  /// may invoke [start] again once login completes.
  Future<void> start() async {
    if (_subscription != null) return;
    _ensureRegistryListener();
    final int? lineId = _resolvePalletizingLineId();
    if (lineId == null) {
      state = state.copyWith(
        status: OperatorDashboardSyncStatus.unauthenticated,
      );
      return;
    }
    _openSubscription(lineId);
  }

  /// Cancels the underlying subscription and returns to idle. Safe to call
  /// multiple times. The summary stays whatever it last was.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _boundPalletizingLineId = null;
    _stopPolling();
    _cancelDebounce();
    state = const OperatorDashboardSyncState.idle();
  }

  void _ensureRegistryListener() {
    _registryListener ??= ref.listen<MultiLineSessionRegistryState>(
      multiLineSessionRegistryProvider,
      (prev, next) => _onRegistryChange(next),
    );
  }

  void _onRegistryChange(MultiLineSessionRegistryState next) {
    final int? lineId = _readPalletizingLineId(next);
    if (lineId == null) {
      // Session for this shift-line just disappeared (logout / cascade).
      // Tear down the subscription and timers; a future login re-starts it.
      if (_subscription != null) {
        _subscription!.cancel();
        _subscription = null;
        _boundPalletizingLineId = null;
        _stopPolling();
        _cancelDebounce();
        state = state.copyWith(
          status: OperatorDashboardSyncStatus.unauthenticated,
        );
      }
      return;
    }
    if (_boundPalletizingLineId != null && _boundPalletizingLineId != lineId) {
      // Palletizing line changed (rare — only possible across re-pairings).
      // Restart against the new id.
      _subscription?.cancel();
      _subscription = null;
      _boundPalletizingLineId = null;
    }
    if (_subscription == null) {
      _openSubscription(lineId);
    }
  }

  void _openSubscription(int palletizingLineId) {
    _boundPalletizingLineId = palletizingLineId;
    final client = ref.read(
      operatorDashboardSseClientForLineProvider(_shiftLineId),
    );
    state = state.copyWith(
      status: OperatorDashboardSyncStatus.connecting,
      clearLastError: true,
    );
    _subscription = client.subscribe(lineId: palletizingLineId).listen(_onItem);
    // Begin the safety-net poll for the life of this subscription.
    _recomputeAndApplyCadence();
  }

  // ─── App lifecycle (§3 / §6) ───────────────────────────────────────────

  /// Called when the app returns to the foreground. The SSE broker has no
  /// event replay, so a REST refresh is the only reliable recovery for
  /// anything that changed while backgrounded — refresh immediately, then
  /// restart the adaptive poll.
  void onAppResumed() {
    _appPaused = false;
    refreshLog(
      'app resumed (shiftLine=$_shiftLineId) → immediate summary refresh',
    );
    _summaryNotifier.refresh();
    _recomputeAndApplyCadence();
  }

  /// Called when the app is backgrounded. Drops the safety-net poll and any
  /// pending debounced refresh; [onAppResumed] restarts them.
  void onAppPaused() {
    _appPaused = true;
    _stopPolling();
    _cancelDebounce();
  }

  // ─── SSE event handling ────────────────────────────────────────────────

  void _onItem(OperatorDashboardStreamItem item) {
    switch (item) {
      case SseConnected():
        state = state.copyWith(
          status: OperatorDashboardSyncStatus.connected,
          clearLastError: true,
        );
        refreshLog(
          'SSE connected (palletizingLine=$_boundPalletizingLineId, '
          'shiftLine=$_shiftLineId) → immediate summary refresh',
        );
        // First connect: converge on a known snapshot before deltas arrive.
        _summaryNotifier.refresh();
      case SseReconnected():
        state = state.copyWith(
          status: OperatorDashboardSyncStatus.connected,
          clearLastError: true,
        );
        refreshLog(
          'SSE reconnected (shiftLine=$_shiftLineId) → immediate summary '
          'refresh',
        );
        // §2 — refetch immediately on reconnect; do not wait for an event.
        _summaryNotifier.refresh();
      case SseTransportError(:final error):
        state = state.copyWith(
          status: OperatorDashboardSyncStatus.reconnecting,
          lastError: error,
        );
        refreshLog('SSE transport error (shiftLine=$_shiftLineId) → '
            'reconnecting: $error');
      case SseEventReceived(:final event):
        _dispatch(event);
    }
    // The SSE link status just changed — the poll cadence may need to move
    // between the connected (slow) and disconnected (medium) tiers (§4).
    _recomputeAndApplyCadence();
  }

  void _dispatch(OperatorDashboardEvent event) {
    state = state.copyWith(lastEventId: event.eventId);
    refreshLog(
      'SSE event received: reason=${event.reason.wireValue} '
      'lineId=${event.lineId} (shiftLine=$_shiftLineId) '
      '→ debounced summary refresh',
    );
    // §1 — every relevant event triggers a debounced REST refresh. REST is
    // the source of truth; the UI converges on its response, not the payload.
    _scheduleDebouncedRefresh();
    // Optimistic roll-level overlay for events that carry a typed payload —
    // instant feedback only; the debounced REST refresh above is what
    // reconciles line lifecycle / operator / takeover / blocked state.
    final OperatorDashboardPayload? payload = event.payload;
    if (payload == null) return;
    switch (payload) {
      case ProductChangedPayload():
        _summaryNotifier.applyProductChanged(payload);
      case RollConsumptionSegmentRecordedPayload():
        _summaryNotifier.applyRollSegmentRecorded(payload);
      case RollContinuedWithNewProductPayload():
        _summaryNotifier.applyRollContinued(payload);
      case RollReturnedRemainingPayload():
        _summaryNotifier.applyRollReturnedRemaining(payload);
      case MachineRollStateUpdatedPayload():
        _summaryNotifier.applyMachineRollState(payload);
    }
  }

  void _scheduleDebouncedRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_config.eventDebounce, () {
      _debounceTimer = null;
      _summaryNotifier.refresh();
    });
  }

  void _cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  // ─── Adaptive poll cadence (§4 / §5) ───────────────────────────────────

  /// (Re)starts the safety-net poll at the cadence implied by the current
  /// SSE link status and summary state. A no-op when the desired cadence is
  /// already running — this is what guarantees a single timer per
  /// shift-line (§6): the timer is only torn down and rebuilt when the tier
  /// genuinely changes.
  void _recomputeAndApplyCadence() {
    if (_subscription == null || _appPaused) {
      _stopPolling();
      return;
    }
    final Duration desired = _desiredPollInterval();
    if (_pollTimer != null && _currentPollInterval == desired) return;
    _pollTimer?.cancel();
    _currentPollInterval = desired;
    _pollTimerGeneration++;
    _pollTimer = Timer.periodic(desired, (_) => _summaryNotifier.refresh());
  }

  Duration _desiredPollInterval() {
    // Fast cadence wins regardless of link health — a line mid-transition
    // must converge quickly even while SSE is healthy (§5).
    if (_summaryRequiresFastPoll()) return _config.fastInterval;
    final bool connected =
        state.status == OperatorDashboardSyncStatus.connected;
    return connected ? _config.stableInterval : _config.disconnectedInterval;
  }

  /// Whether the summary indicates the line is mid-transition / unavailable
  /// and therefore needs the fast poll (§5). A not-yet-loaded summary also
  /// polls fast — the app keeps probing until it has a real snapshot.
  bool _summaryRequiresFastPoll() {
    final ShiftLineSummaryState summaryState = ref.read(
      shiftLineSummaryControllerProvider(_shiftLineId),
    );
    if (summaryState is! SummaryLoaded) return true;
    final summary = summaryState.summary;
    return summary.noActiveOperator ||
        summary.handoverPending ||
        (summary.takeover?.isActive ?? false) ||
        summary.blocked ||
        summary.blockedReason != null ||
        !_lifecycleIsNormal(summary.lineLifecycleStatus);
  }

  /// A null lifecycle string is treated as normal (the field is diagnostic
  /// and often absent); any non-`ACTIVE` value moves the line to fast poll.
  bool _lifecycleIsNormal(String? status) {
    if (status == null) return true;
    final String normalized = status.toUpperCase();
    return normalized == 'ACTIVE' ||
        normalized == 'NORMAL' ||
        normalized == 'RUNNING';
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _currentPollInterval = null;
  }

  ShiftLineSummaryController get _summaryNotifier =>
      ref.read(shiftLineSummaryControllerProvider(_shiftLineId).notifier);

  int? _resolvePalletizingLineId() {
    final MultiLineSessionRegistryState registry = ref.read(
      multiLineSessionRegistryProvider,
    );
    return _readPalletizingLineId(registry);
  }

  int? _readPalletizingLineId(MultiLineSessionRegistryState registry) {
    if (registry is! RegistryActive) return null;
    final RollWorkerSession? session = registry.sessions[_shiftLineId];
    return session?.palletizingLineId;
  }

  // ─── Test hooks ────────────────────────────────────────────────────────

  /// Cadence the running poll timer was created with, or `null` when no
  /// timer is active. Exposed for cadence-tier assertions.
  @visibleForTesting
  Duration? get currentPollInterval => _currentPollInterval;

  /// Number of distinct poll timers created over this controller's life.
  /// A no-op cadence recompute must not advance it (§6 — no duplicate timers).
  @visibleForTesting
  int get pollTimerGeneration => _pollTimerGeneration;
}

final operatorDashboardSyncControllerProvider =
    NotifierProvider.family<
      OperatorDashboardSyncController,
      OperatorDashboardSyncState,
      int
    >(OperatorDashboardSyncController.new);
