import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/data/previous_roll_providers.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/entities/previous_roll_resolution.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/previous_roll_repository.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/controllers/previous_roll_resolution_controller.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/controllers/previous_roll_resolution_state.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/entities/mounted_roll.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/controllers/roll_scan_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/controllers/roll_scan_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockPrevRepo extends Mock implements PreviousRollRepository {}

class _MockScanRepo extends Mock implements RollScanRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

PreviousRollResolution _consumed() => const PreviousRollResolution(
  rollId: 1,
  generatedRollId: '777000000001',
  finalState: PreviousRollFinalState.consumed,
  consumedWeightKg: 250.0,
  remainingWeightKg: 0.0,
  remainderAction: PreviousRollRemainderAction.none,
  eventType: PreviousRollEventType.closedFull,
  reprintAvailable: false,
);

PreviousRollResolution _partiallyReturned() => const PreviousRollResolution(
  rollId: 1,
  generatedRollId: '777000000001',
  finalState: PreviousRollFinalState.partiallyReturned,
  consumedWeightKg: 175.5,
  remainingWeightKg: 75.5,
  remainderAction: PreviousRollRemainderAction.returned,
  eventType: PreviousRollEventType.closedPartialReturn,
  reprintAvailable: true,
);

ProviderContainer _container({
  required PreviousRollRepository prevRepo,
  RollScanRepository? scanRepo,
  RollWorkerAuthRepository? authRepo,
}) {
  final c = ProviderContainer(
    overrides: <Override>[
      previousRollRepositoryProvider.overrideWithValue(prevRepo),
      if (scanRepo != null)
        rollScanRepositoryProvider.overrideWithValue(scanRepo),
      if (authRepo != null)
        rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

MountedRoll _mounted() => const MountedRoll(
  rollId: 1,
  generatedRollId: '777000000001',
  rollTypeId: 70,
  rollTypeRollCode: 'TT-1S B250 White',
  rollTypeDisplayName: 'TT-1S B250',
  colorName: 'White',
  productTypeId: 5,
  productTypeName: 'أحمر 20 كغ',
  consumptionItemId: 5000,
  activeSegmentId: 6000,
  state: 'IN_CONSUMPTION',
  lastKnownWeightKg: 250.0,
);

void main() {
  group('fullConsume', () {
    test('on success → Resolved + RollScan reset to Idle', () async {
      final prev = _MockPrevRepo();
      final scan = _MockScanRepo();
      when(
        () => prev.fullConsume(shiftLineId: kShiftLineId),
      ).thenAnswer((_) async => PreviousRollSuccess(_consumed()));
      // Seed the scan controller as Mounted to verify reset clears it.
      when(
        () => scan.mountRoll(
          shiftLineId: kShiftLineId,
          generatedRollId: '777000000001',
        ),
      ).thenAnswer((_) async => RollScanSuccess(_mounted()));
      final container = _container(prevRepo: prev, scanRepo: scan);

      await container
          .read(rollScanControllerProvider(kShiftLineId).notifier)
          .mountRoll('777000000001');
      expect(
        container.read(rollScanControllerProvider(kShiftLineId)),
        isA<RollScanMounted>(),
      );

      await container
          .read(previousRollResolutionControllerProvider(kShiftLineId).notifier)
          .fullConsume();

      final state = container.read(
        previousRollResolutionControllerProvider(kShiftLineId),
      );
      expect(state, isA<PreviousRollResolved>());
      expect(
        container.read(rollScanControllerProvider(kShiftLineId)),
        isA<RollScanIdle>(),
      );
    });
  });

  group('returnRemaining', () {
    test('on success transitions to Resolved with the resolution', () async {
      final prev = _MockPrevRepo();
      when(
        () => prev.returnRemaining(
          shiftLineId: kShiftLineId,
          remainingWeightKg: 75.5,
        ),
      ).thenAnswer((_) async => PreviousRollSuccess(_partiallyReturned()));
      final container = _container(prevRepo: prev);

      await container
          .read(previousRollResolutionControllerProvider(kShiftLineId).notifier)
          .returnRemaining(75.5);

      final state = container.read(
        previousRollResolutionControllerProvider(kShiftLineId),
      );
      expect(state, isA<PreviousRollResolved>());
      expect(
        (state as PreviousRollResolved).resolution.reprintAvailable,
        isTrue,
      );
    });
  });

  group('sendToGrinding', () {
    test('cascades on SESSION_REQUIRED via auth.notifySessionLost', () async {
      final prev = _MockPrevRepo();
      final authRepo = _MockAuthRepo();
      when(
        () => prev.sendToGrinding(
          shiftLineId: kShiftLineId,
          remainingWeightKg: 40.0,
        ),
      ).thenAnswer(
        (_) async => const PreviousRollFailure(
          BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
        ),
      );
      when(
        () => authRepo.clearStoredToken(kShiftLineId),
      ).thenAnswer((_) async {});
      final container = _container(prevRepo: prev, authRepo: authRepo);

      await container
          .read(previousRollResolutionControllerProvider(kShiftLineId).notifier)
          .sendToGrinding(40.0);

      verify(() => authRepo.clearStoredToken(kShiftLineId)).called(1);
      expect(
        container.read(previousRollResolutionControllerProvider(kShiftLineId)),
        isA<PreviousRollFailureState>(),
      );
    });

    test(
      'on SHIFT_LINE_NOT_ACTIVE also routes through registry.notifySessionLost',
      () async {
        final prev = _MockPrevRepo();
        final authRepo = _MockAuthRepo();
        when(
          () => prev.sendToGrinding(
            shiftLineId: kShiftLineId,
            remainingWeightKg: 40.0,
          ),
        ).thenAnswer(
          (_) async => const PreviousRollFailure(
            BusinessFailure(code: ErrorCode.thermoformingShiftLineNotActive),
          ),
        );
        when(
          () => authRepo.clearStoredToken(kShiftLineId),
        ).thenAnswer((_) async {});
        final container = _container(prevRepo: prev, authRepo: authRepo);

        await container
            .read(
              previousRollResolutionControllerProvider(kShiftLineId).notifier,
            )
            .sendToGrinding(40.0);

        verify(() => authRepo.clearStoredToken(kShiftLineId)).called(1);
      },
    );

    test('on NO_ACTIVE_ROLL_ON_LINE resets the local mount cache', () async {
      final prev = _MockPrevRepo();
      final scan = _MockScanRepo();
      when(
        () => prev.sendToGrinding(
          shiftLineId: kShiftLineId,
          remainingWeightKg: 40.0,
        ),
      ).thenAnswer(
        (_) async => const PreviousRollFailure(
          BusinessFailure(code: ErrorCode.noActiveRollOnLine),
        ),
      );
      when(
        () => scan.mountRoll(
          shiftLineId: kShiftLineId,
          generatedRollId: '777000000001',
        ),
      ).thenAnswer((_) async => RollScanSuccess(_mounted()));
      final container = _container(prevRepo: prev, scanRepo: scan);

      // Seed scan as Mounted.
      await container
          .read(rollScanControllerProvider(kShiftLineId).notifier)
          .mountRoll('777000000001');
      expect(
        container.read(rollScanControllerProvider(kShiftLineId)),
        isA<RollScanMounted>(),
      );

      await container
          .read(previousRollResolutionControllerProvider(kShiftLineId).notifier)
          .sendToGrinding(40.0);

      expect(
        container.read(rollScanControllerProvider(kShiftLineId)),
        isA<RollScanIdle>(),
      );
    });
  });

  group('acknowledge / clearError / reset', () {
    test('acknowledge moves Resolved → Idle', () async {
      final prev = _MockPrevRepo();
      when(
        () => prev.fullConsume(shiftLineId: kShiftLineId),
      ).thenAnswer((_) async => PreviousRollSuccess(_consumed()));
      final container = _container(prevRepo: prev);

      await container
          .read(previousRollResolutionControllerProvider(kShiftLineId).notifier)
          .fullConsume();
      expect(
        container.read(previousRollResolutionControllerProvider(kShiftLineId)),
        isA<PreviousRollResolved>(),
      );

      container
          .read(previousRollResolutionControllerProvider(kShiftLineId).notifier)
          .acknowledge();

      expect(
        container.read(previousRollResolutionControllerProvider(kShiftLineId)),
        isA<PreviousRollIdle>(),
      );
    });

    test('clearError moves FailureState → Idle', () async {
      final prev = _MockPrevRepo();
      when(() => prev.fullConsume(shiftLineId: kShiftLineId)).thenAnswer(
        (_) async => const PreviousRollFailure(
          BusinessFailure(code: ErrorCode.rollBlocked),
        ),
      );
      final container = _container(prevRepo: prev);

      await container
          .read(previousRollResolutionControllerProvider(kShiftLineId).notifier)
          .fullConsume();
      expect(
        container.read(previousRollResolutionControllerProvider(kShiftLineId)),
        isA<PreviousRollFailureState>(),
      );

      container
          .read(previousRollResolutionControllerProvider(kShiftLineId).notifier)
          .clearError();

      expect(
        container.read(previousRollResolutionControllerProvider(kShiftLineId)),
        isA<PreviousRollIdle>(),
      );
    });
  });
}
