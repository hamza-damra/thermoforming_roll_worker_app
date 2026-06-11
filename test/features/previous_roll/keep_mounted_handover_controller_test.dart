import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/data/dto/roll_worker_handover_response.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/data/previous_roll_providers.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/previous_roll_repository.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/controllers/keep_mounted_handover_controller.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/controllers/keep_mounted_handover_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockPrevRepo extends Mock implements PreviousRollRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

RollWorkerHandoverResponse _handover() =>
    RollWorkerHandoverResponse.fromJson(const <String, dynamic>{
      'rollId': 1,
      'generatedRollId': '777000000001',
      'finalState': 'IN_CONSUMPTION',
      'consumedWeightKg': 40.0,
      'currentWeightKg': 60.0,
      'rollRemainsMounted': true,
    });

ProviderContainer _container({
  required PreviousRollRepository prev,
  RollWorkerAuthRepository? auth,
}) {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      previousRollRepositoryProvider.overrideWithValue(prev),
      if (auth != null)
        rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('on success transitions to KeepMountedSucceeded with the response',
      () async {
    final prev = _MockPrevRepo();
    when(
      () => prev.keepMountedHandover(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 60.0,
      ),
    ).thenAnswer((_) async => KeepMountedSuccess(_handover()));
    final container = _container(prev: prev);

    await container
        .read(keepMountedHandoverControllerProvider(kShiftLineId).notifier)
        .submit(60.0);

    final state =
        container.read(keepMountedHandoverControllerProvider(kShiftLineId));
    expect(state, isA<KeepMountedSucceeded>());
    expect((state as KeepMountedSucceeded).response.consumedWeightKg, 40.0);
  });

  test('on validation failure stays in failure (token preserved)', () async {
    final prev = _MockPrevRepo();
    when(
      () => prev.keepMountedHandover(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 1000.0,
      ),
    ).thenAnswer(
      (_) async => const KeepMountedFailure(
        BusinessFailure(code: ErrorCode.invalidRemainingRollWeight),
      ),
    );
    final container = _container(prev: prev);

    await container
        .read(keepMountedHandoverControllerProvider(kShiftLineId).notifier)
        .submit(1000.0);

    expect(
      container.read(keepMountedHandoverControllerProvider(kShiftLineId)),
      isA<KeepMountedHandoverFailure>(),
    );
  });

  test('on SESSION_REQUIRED cascades via registry.notifySessionLost', () async {
    final prev = _MockPrevRepo();
    final auth = _MockAuthRepo();
    when(
      () => prev.keepMountedHandover(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 60.0,
      ),
    ).thenAnswer(
      (_) async => const KeepMountedFailure(
        BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      ),
    );
    when(() => auth.clearStoredToken(kShiftLineId)).thenAnswer((_) async {});
    final container = _container(prev: prev, auth: auth);

    await container
        .read(keepMountedHandoverControllerProvider(kShiftLineId).notifier)
        .submit(60.0);

    verify(() => auth.clearStoredToken(kShiftLineId)).called(1);
    expect(
      container.read(keepMountedHandoverControllerProvider(kShiftLineId)),
      isA<KeepMountedHandoverFailure>(),
    );
  });
}
