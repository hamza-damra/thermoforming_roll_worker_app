import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/data/urgent_announcements_providers.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/domain/entities/manager_announcement.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/domain/urgent_announcements_repository.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/presentation/controllers/manager_announcement_controller.dart';
import 'package:thermoforming_roll_worker/features/urgent_announcements/presentation/controllers/manager_announcement_state.dart';

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

class _MockAnnouncementsRepo extends Mock
    implements UrgentAnnouncementsRepository {}

class _MockRawStorage extends Mock implements FlutterSecureStorage {}

ManagerAnnouncement _ann(int id) =>
    ManagerAnnouncement(id: id, createdAtDisplay: 'time-$id');

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
  });
}
