import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/refresh_log.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_classification.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../../data/urgent_announcements_providers.dart';
import '../../domain/entities/manager_announcement.dart';
import '../../domain/urgent_announcements_repository.dart';
import 'manager_announcement_state.dart';

/// Owns the worker's pending sanitized urgent-manager notices.
///
/// Authoritative source is `GET /urgent-announcements/pending`; the
/// `urgent-manager-announcement` SSE frame is only a best-effort nudge. We
/// (re)fetch pending on: registry becoming active (login / restore), SSE
/// connect / reconnect, every SSE nudge (debounced), and app resume (driven
/// by `BootstrapScreen`).
///
/// Fetching is skipped unless the worker is logged in (`RegistryActive`) — the
/// endpoints need a session token, and the ack is operator-scoped so one ack
/// dismisses the notice across every line the worker holds.
class ManagerAnnouncementController extends Notifier<ManagerAnnouncementState> {
  /// Coalesces a burst of SSE nudges into a single REST refetch.
  Timer? _nudgeDebounce;
  static const Duration _nudgeDebounceWindow = Duration(milliseconds: 250);

  /// One-shot timer armed at the nearest future `expiresAt` so the blocking
  /// modal clears on time instead of at the next nudge / resume / reconnect
  /// (timed-announcements handoff §8).
  Timer? _expiryTimer;

  /// Added to the armed delay so the timer fires just *after* the deadline,
  /// never a hair before it.
  static const Duration _expirySkew = Duration(seconds: 1);

  /// Upper bound on a single armed delay. A garbage far-future `expiresAt`
  /// re-arms on wake instead of creating one monstrous timer.
  static const Duration _maxExpiryDelay = Duration(hours: 12);

  /// Re-arm delay used when a sweep comes due mid-ack — see [_runExpirySweep].
  static const Duration _ackDeferral = Duration(seconds: 2);

  /// Monotonic fetch sequence — a slow `/pending` response whose seq is older
  /// than `_fetchSeq` when it resolves is discarded (out-of-order guard).
  int _fetchSeq = 0;

  @override
  ManagerAnnouncementState build() {
    ref.onDispose(() {
      _nudgeDebounce?.cancel();
      _nudgeDebounce = null;
      _expiryTimer?.cancel();
      _expiryTimer = null;
    });
    ref.listen<MultiLineSessionRegistryState>(
      multiLineSessionRegistryProvider,
      (_, next) => _syncForRegistry(next),
    );
    return ManagerAnnouncementState.empty;
  }

  UrgentAnnouncementsRepository get _repo =>
      ref.read(urgentAnnouncementsRepositoryProvider);

  bool get _loggedIn =>
      ref.read(multiLineSessionRegistryProvider) is RegistryActive;

  // ─── Fetch ────────────────────────────────────────────────────────────────

  /// Refetch `/pending`. No-op when the worker is not logged in (no token).
  /// [trigger] is diagnostic only (login-or-restore / sse-nudge /
  /// sse-connected / app-resume).
  Future<void> fetchPending({String trigger = 'manual'}) async {
    if (!_loggedIn) return;

    final int seq = ++_fetchSeq;
    refreshLog('urgent-announcements fetch #$seq (trigger=$trigger)');
    final PendingAnnouncementsResult result = await _repo.fetchPending();

    // A newer fetch superseded this one, or the worker logged out mid-flight.
    if (seq != _fetchSeq || !_loggedIn) return;

    switch (result) {
      case PendingAnnouncementsSuccess(:final announcements):
        refreshLog('urgent-announcements: ${announcements.length} pending');
        // Replace the queue; leave an in-flight ack (acking / ackError)
        // untouched so a background refetch never resets the button spinner.
        //
        // Note what is NOT done here: nothing is filtered by `expiresAt` on
        // arrival. The server already applied `expiresAt > now` (§4.2), so a
        // row that looks expired against the device clock means the clock is
        // wrong — dropping it would hide a live notice. Only [_runExpirySweep]
        // prunes, and only for a deadline that was still in the future when
        // the timer was armed.
        state = state.copyWith(pending: announcements);
        _armExpiryTimer();
      case PendingAnnouncementsFailure(:final failure):
        // Best-effort fetch: never surface an error to the worker — the next
        // nudge / reconnect / resume retries. Keep whatever is on screen.
        // The fault class is logged so a misconfigured `X-Device-Key` is
        // greppable even though this path stays silent (never the values —
        // `RedactingLoggerInterceptor` redacts both headers).
        refreshLog(
          'urgent-announcements fetch failed (ignored, '
          '${_faultClass(failure)}): $failure',
        );
    }
  }

  /// Coarse fault class for diagnostics only — never shown to the worker.
  String _faultClass(AppFailure failure) {
    if (isDeviceAuthFault(failure)) return 'device-auth';
    if (isSessionLossCascade(failure)) return 'session';
    return 'other';
  }

  // ─── Acknowledge ────────────────────────────────────────────────────────

  /// Acknowledge the front (oldest) notice. Keeps the modal visible with a
  /// spinner until the server confirms; on success removes it from the queue,
  /// on failure surfaces [ManagerAnnouncementState.ackError] for inline retry.
  Future<void> acknowledgeFront() async {
    final ManagerAnnouncement? front = state.front;
    if (front == null || state.acking) return;

    state = state.copyWith(acking: true, clearAckError: true);
    final AckResult result = await _repo.ack(front.id);

    switch (result) {
      case AckSuccess():
        // Drop exactly the acked id (the front may have shifted if a refetch
        // landed mid-ack — match by id, not position).
        final List<ManagerAnnouncement> remaining = <ManagerAnnouncement>[
          for (final ManagerAnnouncement a in state.pending)
            if (a.id != front.id) a,
        ];
        state = state.copyWith(
          pending: remaining,
          acking: false,
          clearAckError: true,
        );
        // The next notice in the queue may have a nearer deadline than the
        // one we just dismissed.
        _armExpiryTimer();
      case AckFailure(:final failure):
        refreshLog(
          'urgent-announcements ack failed (${_faultClass(failure)}): $failure',
        );
        state = state.copyWith(acking: false, ackError: failure);
    }
  }

  // ─── Local expiry (handoff §8 / §14 criterion 5) ──────────────────────────

  /// Earliest `expiresAt` among [pending] that is still in the future relative
  /// to [nowUtc], or null when nothing is due (no deadlines, or every deadline
  /// already appears past — see the device-clock note in [fetchPending]).
  @visibleForTesting
  static DateTime? nextExpiry(
    List<ManagerAnnouncement> pending,
    DateTime nowUtc,
  ) {
    DateTime? soonest;
    for (final ManagerAnnouncement a in pending) {
      final DateTime? at = a.expiresAt?.toUtc();
      if (at == null || !at.isAfter(nowUtc)) continue;
      if (soonest == null || at.isBefore(soonest)) soonest = at;
    }
    return soonest;
  }

  /// (Re)arms the one-shot expiry timer at the nearest future deadline.
  void _armExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;

    final DateTime now = DateTime.now().toUtc();
    final DateTime? due = nextExpiry(state.pending, now);
    if (due == null) return;

    Duration delay = due.difference(now) + _expirySkew;
    if (delay > _maxExpiryDelay) delay = _maxExpiryDelay;

    refreshLog('urgent-announcements expiry armed in ${delay.inSeconds}s');
    _expiryTimer = Timer(delay, _runExpirySweep);
  }

  /// Drops notices whose deadline has passed, then reconciles against the
  /// authoritative endpoint. REST remains the source of truth — the local
  /// prune only removes the modal at the exact second.
  void _runExpirySweep() {
    _expiryTimer = null;
    if (!_loggedIn) return;

    // Mid-ack: the worker has already tapped "فهمت" and the server is
    // deciding. Yanking the card away now would strand the in-flight call and
    // flicker the modal — wait for the ack to settle and sweep after.
    if (state.acking) {
      _expiryTimer = Timer(_ackDeferral, _runExpirySweep);
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    final List<ManagerAnnouncement> live = <ManagerAnnouncement>[
      for (final ManagerAnnouncement a in state.pending)
        if (a.expiresAt == null || a.expiresAt!.toUtc().isAfter(now)) a,
    ];
    if (live.length != state.pending.length) {
      refreshLog(
        'urgent-announcements expired locally: '
        '${state.pending.length - live.length}',
      );
      state = state.copyWith(pending: live);
    }

    // Reconcile: the server is authoritative about what is still pending.
    unawaited(fetchPending(trigger: 'expiry'));
    // `fetchPending` re-arms on success; arm now too so a failed fetch still
    // leaves a timer for the next deadline in the queue.
    _armExpiryTimer();
  }

  // ─── SSE hooks (called by SseLifecycleController) ─────────────────────────

  /// `urgent-manager-announcement` SSE frame arrived — debounce, then refetch.
  void onSseNudge() {
    if (!_loggedIn) return;
    _nudgeDebounce?.cancel();
    _nudgeDebounce = Timer(_nudgeDebounceWindow, () {
      _nudgeDebounce = null;
      unawaited(fetchPending(trigger: 'sse-nudge'));
    });
  }

  /// SSE (re)connected — catch-up fetch in case a nudge was missed offline.
  void onSseConnected() {
    if (!_loggedIn) return;
    unawaited(fetchPending(trigger: 'sse-connected'));
  }

  // ─── Registry transitions ─────────────────────────────────────────────────

  void _syncForRegistry(MultiLineSessionRegistryState next) {
    switch (next) {
      case RegistryActive():
        unawaited(fetchPending(trigger: 'login-or-restore'));
      case RegistryEmpty():
      case RegistryRestoring():
        // Logged out — drop any pending notice and cancel a queued nudge.
        _fetchSeq++; // invalidate any in-flight fetch
        _nudgeDebounce?.cancel();
        _nudgeDebounce = null;
        _expiryTimer?.cancel();
        _expiryTimer = null;
        if (state.hasPending || state.acking || state.ackError != null) {
          state = ManagerAnnouncementState.empty;
        }
    }
  }

  // ─── Test hooks ─────────────────────────────────────────────────────────

  @visibleForTesting
  int get fetchSeq => _fetchSeq;

  /// True while a one-shot expiry timer is armed. Used by tests to assert the
  /// timer is torn down on logout / dispose.
  @visibleForTesting
  bool get hasExpiryTimer => _expiryTimer != null;

  /// Runs the expiry sweep synchronously, as the armed timer would.
  /// `fake_async` is not a dependency of this project, so tests drive the
  /// sweep through this seam instead of advancing a clock.
  @visibleForTesting
  void debugRunExpirySweep() => _runExpirySweep();
}

final NotifierProvider<ManagerAnnouncementController, ManagerAnnouncementState>
managerAnnouncementControllerProvider =
    NotifierProvider<ManagerAnnouncementController, ManagerAnnouncementState>(
      ManagerAnnouncementController.new,
    );
