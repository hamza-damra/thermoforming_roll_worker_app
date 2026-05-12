import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/batch_auth_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/batch_auth_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/batch_auth_state.dart';

class _MockBatchRepo extends Mock implements SessionBatchRepository {}

class _MockIndexRaw extends Mock implements FlutterSecureStorage {}

BatchAuthOutcome _outcome() => BatchAuthOutcome(
  rollWorkerOperatorId: 77,
  rollWorkerName: 'Yusuf',
  sessions: <int, RollWorkerSession>{
    101: RollWorkerSession(
      sessionId: 1,
      rollWorkerOperatorId: 77,
      rollWorkerName: 'Yusuf',
      thermoformingShiftId: 9001,
      thermoformingShiftLineId: 101,
      thermoformingLineId: 11,
      palletizingLineId: 21,
      startedAt: DateTime.parse('2026-05-10T10:00:00Z'),
    ),
  },
);

ProviderContainer _container({required SessionBatchRepository repo}) {
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

  final c = ProviderContainer(
    overrides: <Override>[
      sessionBatchRepositoryProvider.overrideWithValue(repo),
      sessionIndexStorageProvider.overrideWithValue(
        SessionIndexStorage.withStorage(raw),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('happy path → registry seeded, state ends at BatchAuthSuccess', () async {
    final repo = _MockBatchRepo();
    when(
      () => repo.startBatch(
        pin: '1234',
        shiftLineIds: <int>{101},
      ),
    ).thenAnswer((_) async => BatchAuthSuccessResult(_outcome()));
    final container = _container(repo: repo);

    await container
        .read(batchAuthControllerProvider.notifier)
        .submit('1234', <int>{101});

    expect(container.read(batchAuthControllerProvider), isA<BatchAuthSuccess>());
  });

  test(
    'empty Set surfaces ROLL_WORKER_SESSION_BATCH_EMPTY without an API call',
    () async {
      final repo = _MockBatchRepo();
      final container = _container(repo: repo);

      await container
          .read(batchAuthControllerProvider.notifier)
          .submit('1234', <int>{});

      final state = container.read(batchAuthControllerProvider);
      expect(state, isA<BatchAuthFailure>());
      expect(
        ((state as BatchAuthFailure).failure as BusinessFailure).code,
        ErrorCode.rollWorkerSessionBatchEmpty,
      );
      verifyNever(
        () => repo.startBatch(
          pin: any<String>(named: 'pin'),
          shiftLineIds: any<Set<int>>(named: 'shiftLineIds'),
        ),
      );
    },
  );

  test('per-line conflict surfaces conflictShiftLineIds for picker recovery',
      () async {
    final repo = _MockBatchRepo();
    when(
      () => repo.startBatch(
        pin: '1234',
        shiftLineIds: <int>{101, 102},
      ),
    ).thenAnswer(
      (_) async => const BatchAuthFailureResult(
        BusinessFailure(
          code: ErrorCode.rollWorkerSessionLineUsedByOtherWorker,
        ),
        conflictShiftLineIds: <int>{102},
      ),
    );
    final container = _container(repo: repo);

    await container
        .read(batchAuthControllerProvider.notifier)
        .submit('1234', <int>{101, 102});

    final state = container.read(batchAuthControllerProvider);
    expect(state, isA<BatchAuthFailure>());
    expect((state as BatchAuthFailure).conflictShiftLineIds, <int>{102});
  });
}
