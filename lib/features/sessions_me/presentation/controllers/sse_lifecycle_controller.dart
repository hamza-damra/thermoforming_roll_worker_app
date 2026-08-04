import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/refresh_log.dart';
import '../../../shift_line/data/roll_worker_lines_sse_providers.dart';
import '../../../shift_line/domain/entities/roll_worker_lines_event.dart';
import '../../../urgent_announcements/presentation/controllers/manager_announcement_controller.dart';
import 'sessions_me_controller.dart';

/// Owns the single global subscription to `RollWorkerLinesSseClient`
/// (`GET /api/v1/thermoforming-roll-app/events`) for the whole app
/// lifetime. Fans out frames to the picker controller and the post-login
/// `SessionsMeController` via callbacks rather than additional
/// subscriptions, so there is always exactly ONE socket open.
///
/// Boot sequence (called from `BootstrapScreen.initState`):
///   1. `start()` opens the subscription.
///   2. `start()` is idempotent — calling again is a no-op while a
///      subscription is alive.
///   3. The subscription is torn down on `ref.onDispose` (when the
///      provider container is disposed at app shutdown).
///
/// SSE → callback wiring:
///   - `PickerSseConnected` / `PickerSseReconnected` →
///     [SessionsMeController.notifySseConnected]. The picker controller
///     also listens via its own [_pickerListeners].
///   - `PickerSseTransportError` →
///     [SessionsMeController.notifySseDisconnected].
///   - `PickerSseRefreshTriggered` →
///     [SessionsMeController.notifyRefreshTrigger].
///
/// The picker `RollWorkerBootstrapController` registers itself via
/// [addPickerListener] / [removePickerListener] so the existing
/// bootstrap refresh logic remains untouched on the *consumption* side —
/// only the ownership of the SSE subscription moved up here.
class SseLifecycleController extends Notifier<SseLifecycleStatus> {
  StreamSubscription<RollWorkerLinesStreamItem>? _subscription;
  final List<void Function(RollWorkerLinesStreamItem)> _pickerListeners =
      <void Function(RollWorkerLinesStreamItem)>[];

  @override
  SseLifecycleStatus build() {
    ref.onDispose(_stop);
    return SseLifecycleStatus.idle;
  }

  /// Idempotent — calling this while a subscription is alive is a no-op.
  void start() {
    if (_subscription != null) return;
    refreshLog('sse-lifecycle: starting global /events subscription');
    _subscription = ref
        .read(rollWorkerLinesSseClientProvider)
        .subscribe()
        .listen(_onItem);
    state = SseLifecycleStatus.connecting;
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    state = SseLifecycleStatus.idle;
  }

  void addPickerListener(void Function(RollWorkerLinesStreamItem) listener) {
    if (!_pickerListeners.contains(listener)) {
      _pickerListeners.add(listener);
    }
  }

  void removePickerListener(
    void Function(RollWorkerLinesStreamItem) listener,
  ) {
    _pickerListeners.remove(listener);
  }

  void _onItem(RollWorkerLinesStreamItem item) {
    // Fan out to picker listener first (it may be inactive once the worker
    // has logged in — the picker controller decides for itself).
    for (final void Function(RollWorkerLinesStreamItem) l in _pickerListeners) {
      try {
        l(item);
      } catch (e, s) {
        refreshLog('sse-lifecycle picker listener threw: $e\n$s');
      }
    }
    final SessionsMeController sessionsMe = ref.read(
      sessionsMeControllerProvider.notifier,
    );
    final ManagerAnnouncementController announcements = ref.read(
      managerAnnouncementControllerProvider.notifier,
    );
    switch (item) {
      case PickerSseConnected():
        state = SseLifecycleStatus.connected;
        sessionsMe.notifySseConnected(isReconnect: false);
        announcements.onSseConnected();
      case PickerSseReconnected():
        state = SseLifecycleStatus.connected;
        sessionsMe.notifySseConnected(isReconnect: true);
        announcements.onSseConnected();
      case PickerSseTransportError():
        state = SseLifecycleStatus.disconnected;
        sessionsMe.notifySseDisconnected();
      case PickerSseRefreshTriggered():
        sessionsMe.notifyRefreshTrigger();
      case PickerSseUrgentAnnouncement(:final UrgentAnnouncementAction action):
        // Additive + distinct: nudge the announcement notifier only — the
        // existing bootstrap/sessions refresh path is intentionally untouched.
        //
        // Every `action` value takes this same branch on purpose (handoff
        // §11 / §14): the sanitized `/pending` endpoint is authoritative, so
        // refetching is the correct response to CREATED, UPDATED, DEACTIVATED,
        // DELETED and any future value alike. The action is logged, not
        // branched on.
        refreshLog('sse-lifecycle urgent-announcement nudge (${action.name})');
        announcements.onSseNudge();
    }
  }

  // ─── Test hooks ─────────────────────────────────────────────────────────

  @visibleForTesting
  bool get hasSubscription => _subscription != null;

  @visibleForTesting
  int get pickerListenerCount => _pickerListeners.length;
}

/// Status reported by [SseLifecycleController]. Currently used for
/// telemetry / diagnostics only — controllers consume the callback-based
/// API rather than watching this enum.
enum SseLifecycleStatus { idle, connecting, connected, disconnected }

final NotifierProvider<SseLifecycleController, SseLifecycleStatus>
sseLifecycleControllerProvider =
    NotifierProvider<SseLifecycleController, SseLifecycleStatus>(
      SseLifecycleController.new,
    );
