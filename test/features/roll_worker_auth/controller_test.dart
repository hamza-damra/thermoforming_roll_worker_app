import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/roll_worker_auth_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/roll_worker_auth_state.dart';

class _MockRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

RollWorkerSession _activeSession({String? status = 'ACTIVE'}) {
  return RollWorkerSession(
    sessionId: 999,
    rollWorkerOperatorId: 42,
    rollWorkerName: 'Ahmad',
    thermoformingShiftId: 700,
    thermoformingShiftLineId: kShiftLineId,
    thermoformingLineId: 200,
    palletizingLineId: 10,
    startedAt: DateTime.parse('2026-05-08T13:00:00.000Z'),
    status: status,
  );
}

ProviderContainer _container(RollWorkerAuthRepository repo) {
  final c = ProviderContainer(
    overrides: <Override>[
      rollWorkerAuthRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('RollWorkerAuthController.checkSession', () {
    test('ACTIVE session → Authenticated', () async {
      final repo = _MockRepo();
      when(
        () => repo.getCurrentSession(kShiftLineId),
      ).thenAnswer((_) async => RollWorkerAuthSuccess(_activeSession()));
      final container = _container(repo);

      final notifier = container.read(
        rollWorkerAuthControllerProvider(kShiftLineId).notifier,
      );
      await notifier.checkSession();

      final state = container.read(
        rollWorkerAuthControllerProvider(kShiftLineId),
      );
      expect(state, isA<RollWorkerAuthAuthenticated>());
      expect(
        (state as RollWorkerAuthAuthenticated).session.rollWorkerName,
        'Ahmad',
      );
    });

    test('SESSION_REQUIRED → Unauthenticated (no error surfaced)', () async {
      final repo = _MockRepo();
      when(() => repo.getCurrentSession(kShiftLineId)).thenAnswer(
        (_) async => const RollWorkerAuthFailure(
          BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
        ),
      );
      final container = _container(repo);

      await container
          .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
          .checkSession();

      final state = container.read(
        rollWorkerAuthControllerProvider(kShiftLineId),
      );
      expect(state, isA<RollWorkerAuthUnauthenticated>());
      expect((state as RollWorkerAuthUnauthenticated).lastFailure, isNull);
    });

    test('SHIFT_LINE_NOT_ACTIVE → LineGone', () async {
      final repo = _MockRepo();
      when(() => repo.getCurrentSession(kShiftLineId)).thenAnswer(
        (_) async => const RollWorkerAuthFailure(
          BusinessFailure(code: ErrorCode.thermoformingShiftLineNotActive),
        ),
      );
      final container = _container(repo);

      await container
          .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
          .checkSession();

      expect(
        container.read(rollWorkerAuthControllerProvider(kShiftLineId)),
        isA<RollWorkerAuthLineGone>(),
      );
    });
  });

  group('RollWorkerAuthController.login', () {
    test('empty PIN → Unauthenticated with OPERATOR_PIN_INVALID', () async {
      final repo = _MockRepo();
      final container = _container(repo);

      await container
          .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
          .login('');

      final state = container.read(
        rollWorkerAuthControllerProvider(kShiftLineId),
      );
      expect(state, isA<RollWorkerAuthUnauthenticated>());
      final failure = (state as RollWorkerAuthUnauthenticated).lastFailure!;
      expect((failure as BusinessFailure).code, ErrorCode.operatorPinInvalid);
      verifyNever(
        () => repo.login(
          shiftLineId: any<int>(named: 'shiftLineId'),
          pin: any<String>(named: 'pin'),
        ),
      );
    });

    test('success → Authenticated', () async {
      final repo = _MockRepo();
      when(
        () => repo.login(shiftLineId: kShiftLineId, pin: '1234'),
      ).thenAnswer((_) async => RollWorkerAuthSuccess(_activeSession()));
      final container = _container(repo);

      await container
          .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
          .login('1234');

      expect(
        container.read(rollWorkerAuthControllerProvider(kShiftLineId)),
        isA<RollWorkerAuthAuthenticated>(),
      );
    });

    test(
      'ROLL_WORKER_NOT_ALLOWED → Unauthenticated with inline failure',
      () async {
        final repo = _MockRepo();
        when(
          () => repo.login(shiftLineId: kShiftLineId, pin: '1234'),
        ).thenAnswer(
          (_) async => const RollWorkerAuthFailure(
            BusinessFailure(code: ErrorCode.rollWorkerNotAllowed),
          ),
        );
        final container = _container(repo);

        await container
            .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
            .login('1234');

        final state = container.read(
          rollWorkerAuthControllerProvider(kShiftLineId),
        );
        expect(state, isA<RollWorkerAuthUnauthenticated>());
        final f = (state as RollWorkerAuthUnauthenticated).lastFailure!;
        expect((f as BusinessFailure).code, ErrorCode.rollWorkerNotAllowed);
      },
    );

    test('NetworkFailure on login surfaces inline error', () async {
      final repo = _MockRepo();
      when(
        () => repo.login(shiftLineId: kShiftLineId, pin: '1234'),
      ).thenAnswer((_) async => const RollWorkerAuthFailure(NetworkFailure()));
      final container = _container(repo);

      await container
          .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
          .login('1234');

      final state = container.read(
        rollWorkerAuthControllerProvider(kShiftLineId),
      );
      expect(state, isA<RollWorkerAuthUnauthenticated>());
      expect(
        (state as RollWorkerAuthUnauthenticated).lastFailure,
        isA<NetworkFailure>(),
      );
    });
  });

  group('RollWorkerAuthController.logout', () {
    test('clears state and routes to Unauthenticated', () async {
      final repo = _MockRepo();
      when(() => repo.logout(kShiftLineId)).thenAnswer((_) async {});
      final container = _container(repo);

      // First, get to authenticated.
      when(
        () => repo.login(shiftLineId: kShiftLineId, pin: '1234'),
      ).thenAnswer((_) async => RollWorkerAuthSuccess(_activeSession()));
      await container
          .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
          .login('1234');

      await container
          .read(rollWorkerAuthControllerProvider(kShiftLineId).notifier)
          .logout();

      expect(
        container.read(rollWorkerAuthControllerProvider(kShiftLineId)),
        isA<RollWorkerAuthUnauthenticated>(),
      );
      verify(() => repo.logout(kShiftLineId)).called(1);
    });
  });

  group('per-shiftLineId isolation', () {
    test('login on one shift-line does not authenticate another', () async {
      final repo = _MockRepo();
      when(
        () => repo.login(shiftLineId: 800, pin: '1234'),
      ).thenAnswer((_) async => RollWorkerAuthSuccess(_activeSession()));
      final container = _container(repo);

      await container
          .read(rollWorkerAuthControllerProvider(800).notifier)
          .login('1234');

      expect(
        container.read(rollWorkerAuthControllerProvider(800)),
        isA<RollWorkerAuthAuthenticated>(),
      );
      expect(
        container.read(rollWorkerAuthControllerProvider(801)),
        isA<RollWorkerAuthInitial>(),
      );
    });
  });
}
