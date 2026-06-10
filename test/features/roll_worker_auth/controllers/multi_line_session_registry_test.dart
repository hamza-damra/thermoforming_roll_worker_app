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
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/data/sessions_me_providers.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/domain/sessions_me_repository.dart';

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

class _MockIndexRaw extends Mock implements FlutterSecureStorage {}

class _MockSessionsMeRepo extends Mock implements SessionsMeRepository {}

RollWorkerSession _session(int shiftLineId, {String? status = 'ACTIVE'}) =>
    RollWorkerSession(
      sessionId: shiftLineId,
      rollWorkerOperatorId: 77,
      rollWorkerName: 'Yusuf',
      thermoformingShiftId: 9001,
      thermoformingShiftLineId: shiftLineId,
      thermoformingLineId: shiftLineId + 100,
      palletizingLineId: shiftLineId + 200,
      startedAt: DateTime.parse('2026-05-10T10:00:12.123+03:00'),
      status: status,
    );

ProviderContainer _container({
  required RollWorkerAuthRepository auth,
  required SessionIndexStorage index,
  SessionsMeRepository? sessionsMe,
}) {
  final c = ProviderContainer(
    overrides: <Override>[
      rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
      sessionIndexStorageProvider.overrideWithValue(index),
      if (sessionsMe != null)
        sessionsMeRepositoryProvider.overrideWithValue(sessionsMe),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('restoreFromStorage', () {
    test('empty index → RegistryEmpty', () async {
      final auth = _MockAuthRepo();
      final raw = _MockIndexRaw();
      when(
        () => raw.read(key: any<String>(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => raw.write(
          key: any<String>(named: 'key'),
          value: any<String>(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      final container = _container(
        auth: auth,
        index: SessionIndexStorage.withStorage(raw),
      );

      await container
          .read(multiLineSessionRegistryProvider.notifier)
          .restoreFromStorage();

      expect(
        container.read(multiLineSessionRegistryProvider),
        isA<RegistryEmpty>(),
      );
    });

    test(
      'mixed restore: 2 ACTIVE + 1 SESSION_REQUIRED → 2 survive, stale token cleared',
      () async {
        final auth = _MockAuthRepo();
        final raw = _MockIndexRaw();
        when(
          () => raw.read(key: any<String>(named: 'key')),
        ).thenAnswer((_) async => '[101,102,103]');
        when(
          () => raw.write(
            key: any<String>(named: 'key'),
            value: any<String>(named: 'value'),
          ),
        ).thenAnswer((_) async {});

        when(
          () => auth.getCurrentSession(101),
        ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(101)));
        when(
          () => auth.getCurrentSession(102),
        ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(102)));
        when(() => auth.getCurrentSession(103)).thenAnswer(
          (_) async => const RollWorkerAuthFailure(
            BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
          ),
        );
        when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});

        final container = _container(
          auth: auth,
          index: SessionIndexStorage.withStorage(raw),
        );

        await container
            .read(multiLineSessionRegistryProvider.notifier)
            .restoreFromStorage();

        final state = container.read(multiLineSessionRegistryProvider);
        expect(state, isA<RegistryActive>());
        final active = state as RegistryActive;
        expect(active.sessions.keys.toSet(), <int>{101, 102});
        verify(() => auth.clearStoredToken(103)).called(1);
      },
    );

    test('NetworkFailure on one id → id retained, token NOT cleared', () async {
      final auth = _MockAuthRepo();
      final raw = _MockIndexRaw();
      when(
        () => raw.read(key: any<String>(named: 'key')),
      ).thenAnswer((_) async => '[101,102]');
      when(
        () => raw.write(
          key: any<String>(named: 'key'),
          value: any<String>(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => auth.getCurrentSession(101),
      ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(101)));
      when(
        () => auth.getCurrentSession(102),
      ).thenAnswer(
        (_) async => const RollWorkerAuthFailure(NetworkFailure()),
      );
      when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});

      final container = _container(
        auth: auth,
        index: SessionIndexStorage.withStorage(raw),
      );

      await container
          .read(multiLineSessionRegistryProvider.notifier)
          .restoreFromStorage();

      verifyNever(() => auth.clearStoredToken(102));
    });
  });

  group('onBatchSuccess', () {
    test(
      'merges sessions over an empty registry → RegistryActive seeded',
      () async {
        final auth = _MockAuthRepo();
        final raw = _MockIndexRaw();
        when(
          () => raw.read(key: any<String>(named: 'key')),
        ).thenAnswer((_) async => null);
        when(
          () => raw.write(
            key: any<String>(named: 'key'),
            value: any<String>(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        final container = _container(
          auth: auth,
          index: SessionIndexStorage.withStorage(raw),
        );

        await container
            .read(multiLineSessionRegistryProvider.notifier)
            .restoreFromStorage();
        await container
            .read(multiLineSessionRegistryProvider.notifier)
            .onBatchSuccess(<int, RollWorkerSession>{101: _session(101)});

        final state = container.read(multiLineSessionRegistryProvider);
        expect(state, isA<RegistryActive>());
        expect((state as RegistryActive).sessions.keys.toSet(), <int>{101});
        expect(state.activeShiftLineId, 101);
        expect(state.lastEvent, isA<BatchAdded>());
      },
    );

    test(
      'additive: start-batch [81] while 82 is active keeps BOTH lines, '
      'active pointer unchanged (handoff §4 / §6.1)',
      () async {
        final auth = _MockAuthRepo();
        final raw = _MockIndexRaw();
        when(
          () => raw.read(key: any<String>(named: 'key')),
        ).thenAnswer((_) async => null);
        when(
          () => raw.write(
            key: any<String>(named: 'key'),
            value: any<String>(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        final container = _container(
          auth: auth,
          index: SessionIndexStorage.withStorage(raw),
        );
        final notifier = container.read(
          multiLineSessionRegistryProvider.notifier,
        );

        // Worker already active on 82.
        await notifier.onBatchSuccess(<int, RollWorkerSession>{82: _session(82)});
        expect(
          (container.read(multiLineSessionRegistryProvider) as RegistryActive)
              .activeShiftLineId,
          82,
        );

        // Logs into 81 — must MERGE, never replace.
        await notifier.onBatchSuccess(<int, RollWorkerSession>{81: _session(81)});

        final state =
            container.read(multiLineSessionRegistryProvider) as RegistryActive;
        expect(state.sessions.keys.toSet(), <int>{81, 82});
        expect(
          state.activeShiftLineId,
          82,
          reason: 'merging a new line must not steal the active pointer',
        );
        expect(state.lastEvent, isA<BatchAdded>());
      },
    );
  });

  group('logout (per-line)', () {
    test('logout 81 removes ONLY 81 and keeps 82 active', () async {
      final auth = _MockAuthRepo();
      final raw = _MockIndexRaw();
      when(
        () => raw.read(key: any<String>(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => raw.write(
          key: any<String>(named: 'key'),
          value: any<String>(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => auth.logout(any<int>())).thenAnswer((_) async {});

      final container = _container(
        auth: auth,
        index: SessionIndexStorage.withStorage(raw),
      );
      final notifier = container.read(
        multiLineSessionRegistryProvider.notifier,
      );

      await notifier.onBatchSuccess(<int, RollWorkerSession>{
        81: _session(81),
        82: _session(82),
      });
      // 81 is the active pointer (first inserted key).
      await notifier.logout(81);

      final state =
          container.read(multiLineSessionRegistryProvider) as RegistryActive;
      expect(state.sessions.keys.toSet(), <int>{82});
      expect(state.activeShiftLineId, 82);
      verify(() => auth.logout(81)).called(1);
      verifyNever(() => auth.logout(82));
    });
  });

  group('notifySessionLost', () {
    test('on the active line, reassigns active to the next surviving id', () async {
      final auth = _MockAuthRepo();
      final raw = _MockIndexRaw();
      when(
        () => raw.read(key: any<String>(named: 'key')),
      ).thenAnswer((_) async => '[101,102]');
      when(
        () => raw.write(
          key: any<String>(named: 'key'),
          value: any<String>(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => auth.getCurrentSession(101),
      ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(101)));
      when(
        () => auth.getCurrentSession(102),
      ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(102)));
      when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});

      final container = _container(
        auth: auth,
        index: SessionIndexStorage.withStorage(raw),
      );

      await container
          .read(multiLineSessionRegistryProvider.notifier)
          .restoreFromStorage();
      await container
          .read(multiLineSessionRegistryProvider.notifier)
          .notifySessionLost(101);

      final state = container.read(multiLineSessionRegistryProvider);
      expect(state, isA<RegistryActive>());
      final active = state as RegistryActive;
      expect(active.sessions.keys.toSet(), <int>{102});
      expect(active.activeShiftLineId, 102);
      expect(active.lastEvent, isA<LineLost>());
      verify(() => auth.clearStoredToken(101)).called(1);
    });

    test('on the last line, transitions to RegistryEmpty with LineLost event', () async {
      final auth = _MockAuthRepo();
      final raw = _MockIndexRaw();
      when(
        () => raw.read(key: any<String>(named: 'key')),
      ).thenAnswer((_) async => '[101]');
      when(
        () => raw.write(
          key: any<String>(named: 'key'),
          value: any<String>(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => auth.getCurrentSession(101),
      ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(101)));
      when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});

      final container = _container(
        auth: auth,
        index: SessionIndexStorage.withStorage(raw),
      );

      await container
          .read(multiLineSessionRegistryProvider.notifier)
          .restoreFromStorage();
      await container
          .read(multiLineSessionRegistryProvider.notifier)
          .notifySessionLost(101);

      final state = container.read(multiLineSessionRegistryProvider);
      expect(state, isA<RegistryEmpty>());
      expect((state as RegistryEmpty).lastEvent, isA<LineLost>());
    });
  });

  group('logoutAll', () {
    test(
      'success → all lines collapse to RegistryEmpty via /sessions/leave-all',
      () async {
        final auth = _MockAuthRepo();
        final raw = _MockIndexRaw();
        final sessionsMe = _MockSessionsMeRepo();
        when(
          () => raw.read(key: any<String>(named: 'key')),
        ).thenAnswer((_) async => '[101,102]');
        when(
          () => raw.write(
            key: any<String>(named: 'key'),
            value: any<String>(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => auth.getCurrentSession(101),
        ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(101)));
        when(
          () => auth.getCurrentSession(102),
        ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(102)));
        when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});
        when(sessionsMe.leaveAll)
            .thenAnswer((_) async => const LeaveAllSuccess());

        final container = _container(
          auth: auth,
          index: SessionIndexStorage.withStorage(raw),
          sessionsMe: sessionsMe,
        );

        await container
            .read(multiLineSessionRegistryProvider.notifier)
            .restoreFromStorage();

        final result = await container
            .read(multiLineSessionRegistryProvider.notifier)
            .logoutAll();

        // New atomic semantics (handoff §5.4): one /sessions/leave-all
        // call, all lines succeed together.
        expect(result.succeeded, <int>{101, 102});
        expect(result.failed, <int>{});
        verify(sessionsMe.leaveAll).called(1);
        // Per-line /roll-worker-logout is NOT called any more.
        verifyNever(() => auth.logout(any<int>()));
        expect(
          container.read(multiLineSessionRegistryProvider),
          isA<RegistryEmpty>(),
        );
      },
    );

    test(
      'failure → all lines retained with failedRetryable status',
      () async {
        final auth = _MockAuthRepo();
        final raw = _MockIndexRaw();
        final sessionsMe = _MockSessionsMeRepo();
        when(
          () => raw.read(key: any<String>(named: 'key')),
        ).thenAnswer((_) async => '[101,102]');
        when(
          () => raw.write(
            key: any<String>(named: 'key'),
            value: any<String>(named: 'value'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => auth.getCurrentSession(101),
        ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(101)));
        when(
          () => auth.getCurrentSession(102),
        ).thenAnswer((_) async => RollWorkerAuthSuccess(_session(102)));
        when(() => auth.clearStoredToken(any<int>())).thenAnswer((_) async {});
        when(sessionsMe.leaveAll).thenAnswer(
          (_) async => const LeaveAllFailure(NetworkFailure()),
        );

        final container = _container(
          auth: auth,
          index: SessionIndexStorage.withStorage(raw),
          sessionsMe: sessionsMe,
        );

        await container
            .read(multiLineSessionRegistryProvider.notifier)
            .restoreFromStorage();

        final result = await container
            .read(multiLineSessionRegistryProvider.notifier)
            .logoutAll();

        expect(result.succeeded, <int>{});
        expect(result.failed, <int>{101, 102});
        final state = container.read(multiLineSessionRegistryProvider);
        expect(state, isA<RegistryActive>());
        final active = state as RegistryActive;
        expect(active.sessions.keys.toSet(), <int>{101, 102});
        expect(active.logoutStatus[101], LineLogoutStatus.failedRetryable);
        expect(active.logoutStatus[102], LineLogoutStatus.failedRetryable);
      },
    );
  });
}
