import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/biometric_denial.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/batch_auth_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/batch_auth_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/batch_auth_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';

class _MockBatchRepo extends Mock implements SessionBatchRepository {}

class _MockIndexRaw extends Mock implements FlutterSecureStorage {}

const Set<int> _ids = <int>{101, 102};

BatchAuthOutcome _outcome() => BatchAuthOutcome(
  rollWorkerOperatorId: 77,
  rollWorkerName: 'Yusuf',
  sessions: <int, RollWorkerSession>{
    for (final int id in _ids)
      id: RollWorkerSession(
        sessionId: id,
        rollWorkerOperatorId: 77,
        rollWorkerName: 'Yusuf',
        thermoformingShiftId: 9001,
        thermoformingShiftLineId: id,
        thermoformingLineId: id + 100,
        palletizingLineId: id + 200,
        startedAt: DateTime.utc(2026, 9, 24, 8),
      ),
  },
);

BatchAuthFailureResult _denied() => BatchAuthFailureResult(
  BiometricDenialFailure(
    denial: const BiometricDenial(
      code: 'BIOMETRIC_VERIFICATION_REQUIRED',
      message: 'يرجى تمرير البصمة على جهاز البصمة ثم إعادة المحاولة.',
      validitySeconds: 300,
      attemptAvailable: true,
      attemptToken: 'secret-token',
    ),
    statusCode: 403,
  ),
);

ProviderContainer _container(SessionBatchRepository repo) {
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
  late _MockBatchRepo repo;
  late ProviderContainer container;
  BatchAuthController ctrl() =>
      container.read(batchAuthControllerProvider.notifier);
  BatchAuthState state() => container.read(batchAuthControllerProvider);

  setUp(() {
    repo = _MockBatchRepo();
    container = _container(repo);
    when(
      () => repo.startBatch(pin: '1234', shiftLineIds: _ids),
    ).thenAnswer((_) async => _denied());
  });

  test('a biometric 403 is not a failure: BiometricRequired, no session', () async {
    await ctrl().submit('1234', _ids);

    expect(state(), isA<BatchAuthBiometricRequired>());
    expect(
      (state() as BatchAuthBiometricRequired).denial.code,
      'BIOMETRIC_VERIFICATION_REQUIRED',
    );
    expect(
      container.read(multiLineSessionRegistryProvider),
      isNot(isA<RegistryActive>()),
      reason: 'none of the listed lines gets a session',
    );
  });

  test('resubmit re-sends the identical body and leaves state alone', () async {
    await ctrl().submit('1234', _ids);
    final BatchAuthBiometricRequired gate =
        state() as BatchAuthBiometricRequired;

    when(
      () => repo.startBatch(pin: '1234', shiftLineIds: _ids),
    ).thenAnswer((_) async => BatchAuthSuccessResult(_outcome()));
    final BatchAuthResult result = await gate.resubmit();

    expect(result, isA<BatchAuthSuccessResult>());
    verify(() => repo.startBatch(pin: '1234', shiftLineIds: _ids)).called(2);
    // The dialog decides when to hand the outcome back.
    expect(state(), same(gate));
  });

  test('taps on «دخول» while the dialog is open are ignored', () async {
    await ctrl().submit('1234', _ids);
    await ctrl().submit('1234', _ids);
    await ctrl().submit('9999', <int>{101});

    verify(() => repo.startBatch(pin: '1234', shiftLineIds: _ids)).called(1);
    verifyNever(() => repo.startBatch(pin: '9999', shiftLineIds: <int>{101}));
  });

  test('completeBiometricGate(success) seeds the registry like a login', () async {
    await ctrl().submit('1234', _ids);
    await ctrl().completeBiometricGate(BatchAuthSuccessResult(_outcome()));

    expect(state(), isA<BatchAuthSuccess>());
    final registry = container.read(multiLineSessionRegistryProvider);
    expect(registry, isA<RegistryActive>());
    expect((registry as RegistryActive).sessions.keys.toSet(), _ids);
  });

  test('completeBiometricGate(null) — cancel — returns to initial', () async {
    await ctrl().submit('1234', _ids);
    await ctrl().completeBiometricGate(null);
    expect(state(), isA<BatchAuthInitial>());
  });

  test('completeBiometricGate(failure) never re-enters the biometric state', () async {
    await ctrl().submit('1234', _ids);
    await ctrl().completeBiometricGate(_denied());
    expect(state(), isA<BatchAuthFailure>());

    await ctrl().completeBiometricGate(
      const BatchAuthFailureResult(
        BusinessFailure(code: ErrorCode.operatorPinInvalid),
      ),
    );
    expect(state(), isA<BatchAuthFailure>());
  });

  test('reset() drops an attempt whose dialog never opened', () async {
    await ctrl().submit('1234', _ids);
    ctrl().reset();
    expect(state(), isA<BatchAuthInitial>());

    when(
      () => repo.startBatch(pin: '1234', shiftLineIds: _ids),
    ).thenAnswer((_) async => BatchAuthSuccessResult(_outcome()));
    await ctrl().submit('1234', _ids);
    expect(state(), isA<BatchAuthSuccess>());
  });
}
