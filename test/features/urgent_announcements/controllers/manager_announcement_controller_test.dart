import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_lines_event.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/data/urgent_announcements_providers.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/domain/entities/manager_announcement.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/domain/urgent_announcements_repository.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/presentation/controllers/manager_announcement_controller.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/presentation/controllers/manager_announcement_state.dart';

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

class _MockAnnouncementsRepo extends Mock
    implements UrgentAnnouncementsRepository {}

class _MockRawStorage extends Mock implements FlutterSecureStorage {}

ManagerAnnouncement _ann(int id, {DateTime? expiresAt}) => ManagerAnnouncement(
  id: id,
  createdAtDisplay: 'time-$id',
  expiresAt: expiresAt,
);

RollWorkerSession _session(int shiftLineId) => RollWorkerSession(
  sessionId: shiftLineId * 10,
  rollWorkerOperatorId: 7,
  rollWorkerName: 'Ahmad',
  thermoformingShiftId: 900,
  thermoformingShiftLineId: shiftLineId,
  thermoformingLineId: shiftLineId + 100,
  palletizingLineId: shiftLineId + 200,
  startedAt: DateTime.parse('2026-06-09T10:00:00.000+03:00'),
);

class _Harness {
  _Harness() : auth = _MockAuthRepo(), repo = _MockAnnouncementsRepo() {
    final raw = _MockRawStorage();
    when(
      () => raw.read(key: any<String>(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => raw.write(
        key: any<String>(named: 'key'),
        value: any<String>(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});

    // Default fetch: nothing pending (overridden per test before going active).
    when(repo.fetchPending).thenAnswer(
      (_) async => const PendingAnnouncementsSuccess(<ManagerAnnouncement>[]),
    );

    container = ProviderContainer(
      overrides: <Override>[
        rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
        sessionIndexStorageProvider.overrideWithValue(
          SessionIndexStorage.withStorage(raw),
        ),
        urgentAnnouncementsRepositoryProvider.overrideWithValue(repo),
      ],
    );
  }

  final _MockAuthRepo auth;
  final _MockAnnouncementsRepo repo;
  late final ProviderContainer container;

  MultiLineSessionRegistry get registry =>
      container.read(multiLineSessionRegistryProvider.notifier);

  ManagerAnnouncementController get controller =>
      container.read(managerAnnouncementControllerProvider.notifier);

  ManagerAnnouncementState get state =>
      container.read(managerAnnouncementControllerProvider);

  /// Instantiates the controller (registers its registry listener) then logs
  /// the worker into [shiftLineId], which fires the login-triggered fetch.
  Future<void> login({int shiftLineId = 81}) async {
    controller; // force build() so the registry listener is active
    await registry.onBatchSuccess(<int, RollWorkerSession>{
      shiftLineId: _session(shiftLineId),
    });
    await pumpEventQueue();
  }

  void dispose() => container.dispose();
}

void main() {
  group('ManagerAnnouncementController', () {
    test('does not fetch while the worker is not logged in', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      // Registry is RegistryRestoring (never active) → fetch is a no-op.
      await h.controller.fetchPending(trigger: 'test');
      await pumpEventQueue();

      verifyNever(h.repo.fetchPending);
      expect(h.state.hasPending, isFalse);
    });

    test('login triggers a fetch that populates pending (oldest first)', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[
          _ann(1),
          _ann(2),
        ]),
      );

      await h.login();

      expect(h.state.pending.map((ManagerAnnouncement a) => a.id), <int>[1, 2]);
      expect(h.state.front?.id, 1);
    });

    test('ack success removes the front notice and clears spinner', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async =>
            PendingAnnouncementsSuccess(<ManagerAnnouncement>[_ann(1), _ann(2)]),
      );
      when(() => h.repo.ack(any<int>())).thenAnswer((_) async => const AckSuccess());

      await h.login();
      expect(h.state.front?.id, 1);

      await h.controller.acknowledgeFront();
      await pumpEventQueue();

      verify(() => h.repo.ack(1)).called(1);
      expect(h.state.pending.map((ManagerAnnouncement a) => a.id), <int>[2]);
      expect(h.state.acking, isFalse);
      expect(h.state.ackError, isNull);
    });

    test('ack failure keeps the notice visible and surfaces an error', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[_ann(1)]),
      );
      when(
        () => h.repo.ack(any<int>()),
      ).thenAnswer((_) async => const AckFailure(NetworkFailure()));

      await h.login();
      await h.controller.acknowledgeFront();
      await pumpEventQueue();

      // The modal stays (still pending), the spinner is cleared, and an inline
      // error is available for retry.
      expect(h.state.front?.id, 1);
      expect(h.state.acking, isFalse);
      expect(h.state.ackError, isA<NetworkFailure>());
    });

    test('a successful retry after a failed ack dismisses the notice', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[_ann(1)]),
      );
      when(
        () => h.repo.ack(any<int>()),
      ).thenAnswer((_) async => const AckFailure(NetworkFailure()));

      await h.login();
      await h.controller.acknowledgeFront();
      await pumpEventQueue();
      expect(h.state.ackError, isNotNull);

      // Retry now succeeds.
      when(() => h.repo.ack(any<int>())).thenAnswer((_) async => const AckSuccess());
      await h.controller.acknowledgeFront();
      await pumpEventQueue();

      expect(h.state.hasPending, isFalse);
      expect(h.state.ackError, isNull);
    });

    test('logout clears any pending notice', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[_ann(1)]),
      );
      await h.login();
      expect(h.state.hasPending, isTrue);

      await h.registry.notifySessionLost(81);
      await pumpEventQueue();

      expect(h.state.hasPending, isFalse);
    });

    test('a device-key fault on fetch is swallowed, not surfaced', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[_ann(1)]),
      );
      await h.login();
      expect(h.state.hasPending, isTrue);

      // Device key goes bad mid-shift. The fetch path is best-effort: keep
      // what is on screen, never surface an error, never log the worker out.
      when(h.repo.fetchPending).thenAnswer(
        (_) async => const PendingAnnouncementsFailure(
          BusinessFailure(
            code: ErrorCode.authInvalidCredentials,
            statusCode: 401,
          ),
        ),
      );
      await h.controller.fetchPending(trigger: 'test');
      await pumpEventQueue();

      expect(h.state.front?.id, 1, reason: 'existing notice is preserved');
      expect(h.state.ackError, isNull);
    });
  });

  // ─── SSE nudge fan-out (handoff §12 / §14 criterion 1) ────────────────────

  group('ManagerAnnouncementController SSE nudge', () {
    for (final UrgentAnnouncementAction action
        in UrgentAnnouncementAction.values) {
      test('a ${action.name} nudge triggers exactly one refetch', () async {
        final h = _Harness();
        addTearDown(h.dispose);

        await h.login();
        // The login fetch already happened; count only what the nudge causes.
        clearInteractions(h.repo);

        // The controller takes no action argument on purpose — every value
        // funnels through the same nudge entry point, which is precisely the
        // property under test.
        h.controller.onSseNudge();
        await _pastDebounce();

        verify(h.repo.fetchPending).called(1);
      });
    }

    test('a burst of nudges of mixed actions coalesces into one refetch',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);

      await h.login();
      clearInteractions(h.repo);

      // CREATED then UPDATED then DEACTIVATED arriving back-to-back.
      h.controller.onSseNudge();
      h.controller.onSseNudge();
      h.controller.onSseNudge();
      await _pastDebounce();

      verify(h.repo.fetchPending).called(1);
    });

    test('a nudge while logged out does not fetch', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      h.controller.onSseNudge();
      await _pastDebounce();

      verifyNever(h.repo.fetchPending);
    });
  });

  // ─── Local expiry (handoff §8 / §14 criterion 5) ──────────────────────────

  group('ManagerAnnouncementController expiry', () {
    test('nextExpiry picks the soonest deadline still in the future', () {
      final DateTime now = DateTime.utc(2026, 7, 31, 10);

      expect(
        ManagerAnnouncementController.nextExpiry(
          <ManagerAnnouncement>[
            _ann(1, expiresAt: now.add(const Duration(hours: 2))),
            _ann(2, expiresAt: now.add(const Duration(minutes: 5))),
            _ann(3), // never expires
          ],
          now,
        ),
        now.add(const Duration(minutes: 5)),
      );
    });

    test('nextExpiry ignores past and exactly-now deadlines', () {
      final DateTime now = DateTime.utc(2026, 7, 31, 10);

      expect(
        ManagerAnnouncementController.nextExpiry(
          <ManagerAnnouncement>[
            _ann(1, expiresAt: now.subtract(const Duration(minutes: 1))),
            _ann(2, expiresAt: now), // boundary is exclusive
          ],
          now,
        ),
        isNull,
      );
    });

    test('nextExpiry returns null when nothing has a deadline', () {
      expect(
        ManagerAnnouncementController.nextExpiry(
          <ManagerAnnouncement>[_ann(1), _ann(2)],
          DateTime.utc(2026, 7, 31, 10),
        ),
        isNull,
      );
    });

    test('a future deadline arms the timer; no deadline arms nothing',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[
          _ann(1, expiresAt: _inFuture(const Duration(hours: 1))),
        ]),
      );
      await h.login();

      expect(h.controller.hasExpiryTimer, isTrue);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[_ann(2)]),
      );
      await h.controller.fetchPending(trigger: 'test');
      await pumpEventQueue();

      expect(h.controller.hasExpiryTimer, isFalse);
    });

    test('the sweep drops an expired notice and refetches to reconcile',
        () async {
      final h = _Harness();
      addTearDown(h.dispose);

      // Two notices: #1 expires imminently, #2 much later.
      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[
          _ann(1, expiresAt: _inFuture(const Duration(milliseconds: 30))),
          _ann(2, expiresAt: _inFuture(const Duration(hours: 4))),
        ]),
      );
      await h.login();
      expect(h.state.front?.id, 1);

      // Let #1's deadline pass, then run the sweep the armed timer would run.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // The reconciling refetch returns only the survivor.
      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[
          _ann(2, expiresAt: _inFuture(const Duration(hours: 4))),
        ]),
      );
      clearInteractions(h.repo);

      h.controller.debugRunExpirySweep();

      // Pruned locally and immediately — before the network round-trip.
      expect(h.state.pending.map((ManagerAnnouncement a) => a.id), <int>[2]);
      await pumpEventQueue();
      // REST stays authoritative: the sweep always reconciles.
      verify(h.repo.fetchPending).called(1);
      // #2 still has a future deadline, so the timer re-arms.
      expect(h.controller.hasExpiryTimer, isTrue);
    });

    test(
      'a notice that already looks expired on ARRIVAL is kept — the server '
      'already excluded expired rows, so the device clock is what is wrong',
      () async {
        final h = _Harness();
        addTearDown(h.dispose);

        when(h.repo.fetchPending).thenAnswer(
          (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[
            _ann(1, expiresAt: _inFuture(const Duration(hours: -3))),
          ]),
        );
        await h.login();

        expect(h.state.front?.id, 1);
        // Nothing to arm (no future deadline) → degrades to the old
        // "clears on the next refetch" behaviour rather than hiding a live
        // notice.
        expect(h.controller.hasExpiryTimer, isFalse);
      },
    );

    test('the sweep defers while an ack is in flight', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      final Completer<AckResult> ackGate = Completer<AckResult>();
      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[
          _ann(1, expiresAt: _inFuture(const Duration(milliseconds: 20))),
        ]),
      );
      when(() => h.repo.ack(any<int>())).thenAnswer((_) => ackGate.future);

      await h.login();
      // Worker taps "فهمت"; the server has not answered yet.
      unawaited(h.controller.acknowledgeFront());
      await pumpEventQueue();
      expect(h.state.acking, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 40));
      h.controller.debugRunExpirySweep();

      // The card is NOT yanked out from under the in-flight ack.
      expect(h.state.front?.id, 1);
      expect(h.controller.hasExpiryTimer, isTrue, reason: 'sweep re-armed');

      ackGate.complete(const AckSuccess());
      await pumpEventQueue();
      expect(h.state.hasPending, isFalse);
    });

    test('logout cancels the armed expiry timer', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[
          _ann(1, expiresAt: _inFuture(const Duration(hours: 1))),
        ]),
      );
      await h.login();
      expect(h.controller.hasExpiryTimer, isTrue);

      await h.registry.notifySessionLost(81);
      await pumpEventQueue();

      expect(h.controller.hasExpiryTimer, isFalse);
      expect(h.state.hasPending, isFalse);
    });

    test('a sweep after logout is inert', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[
          _ann(1, expiresAt: _inFuture(const Duration(milliseconds: 10))),
        ]),
      );
      await h.login();
      await h.registry.notifySessionLost(81);
      await pumpEventQueue();
      clearInteractions(h.repo);

      h.controller.debugRunExpirySweep();
      await pumpEventQueue();

      verifyNever(h.repo.fetchPending);
    });

    test('acking the front re-arms for the next notice deadline', () async {
      final h = _Harness();
      addTearDown(h.dispose);

      when(h.repo.fetchPending).thenAnswer(
        (_) async => PendingAnnouncementsSuccess(<ManagerAnnouncement>[
          _ann(1), // no deadline
          _ann(2, expiresAt: _inFuture(const Duration(hours: 2))),
        ]),
      );
      when(() => h.repo.ack(any<int>())).thenAnswer((_) async => const AckSuccess());

      await h.login();
      await h.controller.acknowledgeFront();
      await pumpEventQueue();

      expect(h.state.front?.id, 2);
      expect(h.controller.hasExpiryTimer, isTrue);
    });
  });
}

/// Waits past the controller's 250 ms nudge debounce window.
Future<void> _pastDebounce() async {
  await Future<void>.delayed(const Duration(milliseconds: 320));
  await pumpEventQueue();
}

DateTime _inFuture(Duration d) => DateTime.now().toUtc().add(d);
