import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/refresh_log.dart';
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

  /// Monotonic fetch sequence — a slow `/pending` response whose seq is older
  /// than `_fetchSeq` when it resolves is discarded (out-of-order guard).
  int _fetchSeq = 0;

  @override
  ManagerAnnouncementState build() {
    ref.onDispose(() {
      _nudgeDebounce?.cancel();
      _nudgeDebounce = null;
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
        state = state.copyWith(pending: announcements);
      case PendingAnnouncementsFailure(:final failure):
        // Best-effort fetch: never surface an error to the worker — the next
        // nudge / reconnect / resume retries. Keep whatever is on screen.
        refreshLog('urgent-announcements fetch failed (ignored): $failure');
    }
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
      case AckFailure(:final failure):
        refreshLog('urgent-announcements ack failed: $failure');
        state = state.copyWith(acking: false, ackError: failure);
    }
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
        if (state.hasPending || state.acking || state.ackError != null) {
          state = ManagerAnnouncementState.empty;
        }
    }
  }

  // ─── Test hooks ─────────────────────────────────────────────────────────

  @visibleForTesting
  int get fetchSeq => _fetchSeq;
}

final NotifierProvider<ManagerAnnouncementController, ManagerAnnouncementState>
managerAnnouncementControllerProvider =
    NotifierProvider<ManagerAnnouncementController, ManagerAnnouncementState>(
      ManagerAnnouncementController.new,
    );
