import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/dto/roll_worker_takeover_request.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/dto/roll_worker_takeover_response.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/batch_auth_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_takeover.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/takeover_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/takeover_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/takeover_state.dart';

class _MockTakeoverRepo extends Mock implements TakeoverRepository {}

class _MockBatchRepo extends Mock implements SessionBatchRepository {}

class _MockIndexRaw extends Mock implements FlutterSecureStorage {}

const int kShiftLineId = 80;

RollWorkerSession _session(int id) => RollWorkerSession(
  sessionId: id,
  rollWorkerOperatorId: 5,
  rollWorkerName: 'باسم',
  thermoformingShiftId: 9001,
  thermoformingShiftLineId: id,
  thermoformingLineId: id + 100,
  palletizingLineId: id + 200,
  startedAt: DateTime.parse('2026-06-01T08:00:00.000+03:00'),
  status: 'ACTIVE',
);

RollWorkerTakeoverResponse _freshSuccess() =>
    RollWorkerTakeoverResponse.fromJson(const <String, dynamic>{
      'alreadyProcessed': false,
      'sessionToken': 'tok',
      'action': 'ROLL_REMAINS_MOUNTED',
      'rollClosed': false,
      'rollRemainsMounted': true,
      'currentWeightKg': 60.0,
    });

ProviderContainer _container({
  required TakeoverRepository takeover,
  required SessionBatchRepository batch,
}) {
  final _MockIndexRaw raw = _MockIndexRaw();
  when(() => raw.read(key: any<String>(named: 'key')))
      .thenAnswer((_) async => null);
  when(
    () => raw.write(
      key: any<String>(named: 'key'),
      value: any<String>(named: 'value'),
    ),
  ).thenAnswer((_) async {});
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      takeoverRepositoryProvider.overrideWithValue(takeover),
      sessionBatchRepositoryProvider.overrideWithValue(batch),
      sessionIndexStorageProvider.overrideWithValue(
        SessionIndexStorage.withStorage(raw),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const RollWorkerTakeoverRequest(
        shiftLineId: kShiftLineId,
        incomingOperatorPin: '0000',
        action: RollWorkerTakeoverAction.fullConsumptionAndClose,
        clientRequestId: 'fallback',
      ),
    );
    registerFallbackValue(<int>{});
  });

  void stubBatchSuccess(SessionBatchRepository batch) {
    when(
      () => batch.startBatch(
        pin: any<String>(named: 'pin'),
        shiftLineIds: any<Set<int>>(named: 'shiftLineIds'),
      ),
    ).thenAnswer(
      (_) async => BatchAuthSuccessResult(
        BatchAuthOutcome(
          rollWorkerOperatorId: 5,
          rollWorkerName: 'باسم',
          sessions: <int, RollWorkerSession>{kShiftLineId: _session(kShiftLineId)},
        ),
      ),
    );
  }

  test('success → re-login seeds the registry; state idle; cid cleared', () async {
    final takeover = _MockTakeoverRepo();
    final batch = _MockBatchRepo();
    when(() => takeover.takeover(any()))
        .thenAnswer((_) async => TakeoverSuccess(_freshSuccess()));
    stubBatchSuccess(batch);
    final container = _container(takeover: takeover, batch: batch);

    await container
        .read(takeoverControllerProvider(kShiftLineId).notifier)
        .submit(
          action: RollWorkerTakeoverAction.rollRemainsMounted,
          pin: '1234',
          currentWeightKg: 60.0,
        );

    expect(
      container.read(takeoverControllerProvider(kShiftLineId)),
      isA<TakeoverIdle>(),
    );
    expect(
      container.read(takeoverControllerProvider(kShiftLineId).notifier)
          .clientRequestId,
      isNull,
    );
    // Registry seeded for the line via the re-login.
    final registry = container.read(multiLineSessionRegistryProvider);
    expect(registry, isA<RegistryActive>());
    expect((registry as RegistryActive).sessions.keys, contains(kShiftLineId));
    verify(
      () => batch.startBatch(
        pin: '1234',
        shiftLineIds: <int>{kShiftLineId},
      ),
    ).called(1);
  });

  test('generates ONE clientRequestId, reused on retry, cleared on success',
      () async {
    final takeover = _MockTakeoverRepo();
    final batch = _MockBatchRepo();
    final List<TakeoverResult> results = <TakeoverResult>[
      const TakeoverFailure(NetworkFailure()),
      TakeoverSuccess(_freshSuccess()),
    ];
    when(() => takeover.takeover(any()))
        .thenAnswer((_) async => results.removeAt(0));
    stubBatchSuccess(batch);
    final container = _container(takeover: takeover, batch: batch);
    final notifier =
        container.read(takeoverControllerProvider(kShiftLineId).notifier);

    // First attempt fails — cid retained.
    await notifier.submit(
      action: RollWorkerTakeoverAction.fullConsumptionAndClose,
      pin: '1234',
    );
    expect(
      container.read(takeoverControllerProvider(kShiftLineId)),
      isA<TakeoverFailureState>(),
    );
    final String? cidAfterFail = notifier.clientRequestId;
    expect(cidAfterFail, isNotNull);

    // Retry succeeds — cid cleared.
    await notifier.submit(
      action: RollWorkerTakeoverAction.fullConsumptionAndClose,
      pin: '1234',
    );
    expect(notifier.clientRequestId, isNull);

    final List<dynamic> captured =
        verify(() => takeover.takeover(captureAny())).captured;
    final RollWorkerTakeoverRequest req1 =
        captured[0] as RollWorkerTakeoverRequest;
    final RollWorkerTakeoverRequest req2 =
        captured[1] as RollWorkerTakeoverRequest;
    expect(req1.clientRequestId, isNotEmpty);
    expect(req2.clientRequestId, req1.clientRequestId);
  });

  test('double-submit is guarded (second call is a no-op)', () async {
    final takeover = _MockTakeoverRepo();
    final batch = _MockBatchRepo();
    final Completer<TakeoverResult> gate = Completer<TakeoverResult>();
    when(() => takeover.takeover(any())).thenAnswer((_) => gate.future);
    final container = _container(takeover: takeover, batch: batch);
    final notifier =
        container.read(takeoverControllerProvider(kShiftLineId).notifier);

    final Future<void> first = notifier.submit(
      action: RollWorkerTakeoverAction.fullConsumptionAndClose,
      pin: '1234',
    );
    final Future<void> second = notifier.submit(
      action: RollWorkerTakeoverAction.fullConsumptionAndClose,
      pin: '1234',
    );
    gate.complete(const TakeoverFailure(NetworkFailure()));
    await Future.wait(<Future<void>>[first, second]);

    verify(() => takeover.takeover(any())).called(1);
  });

  test('re-login failure after a successful takeover surfaces a failure',
      () async {
    final takeover = _MockTakeoverRepo();
    final batch = _MockBatchRepo();
    when(() => takeover.takeover(any()))
        .thenAnswer((_) async => TakeoverSuccess(_freshSuccess()));
    when(
      () => batch.startBatch(
        pin: any<String>(named: 'pin'),
        shiftLineIds: any<Set<int>>(named: 'shiftLineIds'),
      ),
    ).thenAnswer(
      (_) async => const BatchAuthFailureResult(
        BusinessFailure(code: ErrorCode.operatorPinInvalid),
      ),
    );
    final container = _container(takeover: takeover, batch: batch);

    await container
        .read(takeoverControllerProvider(kShiftLineId).notifier)
        .submit(
          action: RollWorkerTakeoverAction.fullConsumptionAndClose,
          pin: '1234',
        );

    expect(
      container.read(takeoverControllerProvider(kShiftLineId)),
      isA<TakeoverFailureState>(),
    );
  });

  test('cancel clears the clientRequestId and resets to idle', () async {
    final takeover = _MockTakeoverRepo();
    final batch = _MockBatchRepo();
    when(() => takeover.takeover(any()))
        .thenAnswer((_) async => const TakeoverFailure(NetworkFailure()));
    final container = _container(takeover: takeover, batch: batch);
    final notifier =
        container.read(takeoverControllerProvider(kShiftLineId).notifier);

    await notifier.submit(
      action: RollWorkerTakeoverAction.fullConsumptionAndClose,
      pin: '1234',
    );
    expect(notifier.clientRequestId, isNotNull);

    notifier.cancel();
    expect(notifier.clientRequestId, isNull);
    expect(
      container.read(takeoverControllerProvider(kShiftLineId)),
      isA<TakeoverIdle>(),
    );
  });
}
