import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/entities/mounted_roll.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/entities/roll_scan_warning.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/controllers/roll_scan_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/controllers/roll_scan_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockScanRepo extends Mock implements RollScanRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

MountedRoll _mounted({
  String id = '777000000001',
  double lastKnownWeightKg = 250.0,
  int consumptionItemId = 5000,
  int activeSegmentId = 6000,
}) => MountedRoll(
  rollId: 1,
  generatedRollId: id,
  rollTypeId: 70,
  rollTypeRollCode: 'TT-1S B250 White',
  rollTypeDisplayName: 'TT-1S B250',
  colorName: 'White',
  productTypeId: 5,
  productTypeName: 'أحمر',
  consumptionItemId: consumptionItemId,
  activeSegmentId: activeSegmentId,
  state: 'IN_CONSUMPTION',
  lastKnownWeightKg: lastKnownWeightKg,
);

ProviderContainer _container({
  required RollScanRepository scanRepo,
  RollWorkerAuthRepository? authRepo,
}) {
  final c = ProviderContainer(
    overrides: <Override>[
      rollScanRepositoryProvider.overrideWithValue(scanRepo),
      if (authRepo != null)
        rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('RollScanController.isValidGeneratedRollId', () {
    test('accepts exactly 12 digits', () {
      expect(RollScanController.isValidGeneratedRollId('777000000001'), isTrue);
    });

    test('rejects non-12-digit input', () {
      expect(RollScanController.isValidGeneratedRollId(''), isFalse);
      expect(RollScanController.isValidGeneratedRollId('12345678901'), isFalse);
      expect(
        RollScanController.isValidGeneratedRollId('1234567890123'),
        isFalse,
      );
      expect(
        RollScanController.isValidGeneratedRollId('77700000000a'),
        isFalse,
      );
    });
  });

  group('RollScanController.mountRoll', () {
    test(
      'invalid generatedRollId surfaces BusinessFailure(rollNotFound) without calling repo',
      () async {
        final scanRepo = _MockScanRepo();
        final container = _container(scanRepo: scanRepo);

        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('not-12-digits');

        final state = container.read(rollScanControllerProvider(kShiftLineId));
        expect(state, isA<RollScanFailureState>());
        expect(
          ((state as RollScanFailureState).failure as BusinessFailure).code,
          ErrorCode.rollNotFound,
        );
        verifyNever(
          () => scanRepo.mountRoll(
            shiftLineId: any<int>(named: 'shiftLineId'),
            generatedRollId: any<String>(named: 'generatedRollId'),
          ),
        );
      },
    );

    test('on success transitions to RollScanMounted', () async {
      final scanRepo = _MockScanRepo();
      when(
        () => scanRepo.mountRoll(
          shiftLineId: kShiftLineId,
          generatedRollId: '777000000001',
        ),
      ).thenAnswer((_) async => RollScanSuccess(_mounted()));
      final container = _container(scanRepo: scanRepo);

      await container
          .read(rollScanControllerProvider(kShiftLineId).notifier)
          .mountRoll('777000000001');

      final state = container.read(rollScanControllerProvider(kShiftLineId));
      expect(state, isA<RollScanMounted>());
      expect((state as RollScanMounted).roll.generatedRollId, '777000000001');
      expect(state.warnings, isEmpty);
    });

    test(
      'remount of PARTIALLY_RETURNED roll succeeds with remainder weight as '
      'lastKnownWeightKg (backend returns IN_CONSUMPTION; shape identical to a '
      'fresh mount — controller MUST NOT branch on prior state)',
      () async {
        final scanRepo = _MockScanRepo();
        // Simulates the new backend behavior: a roll previously closed with
        // RETURN_REMAINING (40 kg saved) is rescanned. The backend creates a
        // new consumption item/segment starting from 40 kg and responds with
        // state=IN_CONSUMPTION. The Flutter controller cannot tell this apart
        // from a fresh mount, which is intentional per handoff.
        when(
          () => scanRepo.mountRoll(
            shiftLineId: kShiftLineId,
            generatedRollId: '777000000001',
          ),
        ).thenAnswer(
          (_) async => RollScanSuccess(
            _mounted(
              lastKnownWeightKg: 40.0,
              consumptionItemId: 5101,
              activeSegmentId: 6101,
            ),
          ),
        );
        final container = _container(scanRepo: scanRepo);

        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('777000000001');

        final state = container.read(rollScanControllerProvider(kShiftLineId));
        expect(state, isA<RollScanMounted>());
        final mounted = state as RollScanMounted;
        expect(mounted.roll.generatedRollId, '777000000001');
        // Critical assertion: start weight comes from the backend response,
        // not from any cached original `Roll.actualWeightKg`.
        expect(mounted.roll.lastKnownWeightKg, 40.0);
        expect(mounted.roll.state, 'IN_CONSUMPTION');
        expect(mounted.roll.consumptionItemId, 5101);
        expect(mounted.roll.activeSegmentId, 6101);
      },
    );

    test(
      'on success carrying ROLL_CURING_MAXIMUM_EXCEEDED, warnings flow into '
      'RollScanMounted',
      () async {
        final scanRepo = _MockScanRepo();
        const warning = RollScanWarning(
          code: 'ROLL_CURING_MAXIMUM_EXCEEDED',
          severity: 'WARNING',
          message: 'تنبيه: عمر هذا الرول تجاوز الحد الأعلى للحضانة.',
          payload: <String, Object?>{
            'rollCode': '777000000001',
            'maxCuringDays': 7,
            'actualAgeDays': 13.13,
          },
        );
        when(
          () => scanRepo.mountRoll(
            shiftLineId: kShiftLineId,
            generatedRollId: '777000000001',
          ),
        ).thenAnswer(
          (_) async => RollScanSuccess(
            _mounted(),
            warnings: const <RollScanWarning>[warning],
          ),
        );
        final container = _container(scanRepo: scanRepo);

        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('777000000001');

        final state = container.read(rollScanControllerProvider(kShiftLineId));
        expect(state, isA<RollScanMounted>());
        final mounted = state as RollScanMounted;
        expect(mounted.warnings, hasLength(1));
        expect(mounted.warnings.first.code, 'ROLL_CURING_MAXIMUM_EXCEEDED');
        expect(mounted.warnings.first.payload['maxCuringDays'], 7);
      },
    );

    test(
      'ROLL_CURING_MINIMUM_NOT_MET surfaces a blocking BusinessFailure '
      'without clearing token',
      () async {
        final scanRepo = _MockScanRepo();
        final authRepo = _MockAuthRepo();
        when(
          () => scanRepo.mountRoll(
            shiftLineId: kShiftLineId,
            generatedRollId: '777000000001',
          ),
        ).thenAnswer(
          (_) async => const RollScanFailure(
            BusinessFailure(
              code: ErrorCode.rollCuringMinimumNotMet,
              statusCode: 409,
              serverMessage:
                  'لا يمكن تركيب هذا الرول الآن. مدة الحضانة المطلوبة 5 يوم.',
              details: <String, Object?>{
                'minCuringDays': 5,
                'actualAgeHours': 48,
                'actualAgeDays': 2.0,
              },
            ),
          ),
        );
        final container = _container(scanRepo: scanRepo, authRepo: authRepo);

        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('777000000001');

        final state = container.read(rollScanControllerProvider(kShiftLineId));
        expect(state, isA<RollScanFailureState>());
        final failure = (state as RollScanFailureState).failure;
        expect(failure, isA<BusinessFailure>());
        expect(
          (failure as BusinessFailure).code,
          ErrorCode.rollCuringMinimumNotMet,
        );
        expect(failure.statusCode, 409);
        expect(failure.details?['minCuringDays'], 5);
        // Curing failures are not session/line failures — registry MUST NOT
        // clear the token.
        verifyNever(() => authRepo.clearStoredToken(any<int>()));
      },
    );

    test(
      'ROLL_NOT_FOUND surfaces inline failure and preserves previous mount',
      () async {
        final scanRepo = _MockScanRepo();
        when(
          () => scanRepo.mountRoll(
            shiftLineId: kShiftLineId,
            generatedRollId: '777000000001',
          ),
        ).thenAnswer((_) async => RollScanSuccess(_mounted()));
        when(
          () => scanRepo.mountRoll(
            shiftLineId: kShiftLineId,
            generatedRollId: '777000000099',
          ),
        ).thenAnswer(
          (_) async => const RollScanFailure(
            BusinessFailure(code: ErrorCode.rollNotFound),
          ),
        );
        final container = _container(scanRepo: scanRepo);

        // First, get a mount.
        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('777000000001');
        // Then a failed second attempt.
        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('777000000099');

        final state = container.read(rollScanControllerProvider(kShiftLineId));
        expect(state, isA<RollScanFailureState>());
        final failureState = state as RollScanFailureState;
        expect(failureState.previous?.generatedRollId, '777000000001');
        expect(
          (failureState.failure as BusinessFailure).code,
          ErrorCode.rollNotFound,
        );
      },
    );

    test(
      'SESSION_REQUIRED triggers registry.notifySessionLost (clears token)',
      () async {
        final scanRepo = _MockScanRepo();
        final authRepo = _MockAuthRepo();
        when(
          () => scanRepo.mountRoll(
            shiftLineId: kShiftLineId,
            generatedRollId: '777000000001',
          ),
        ).thenAnswer(
          (_) async => const RollScanFailure(
            BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
          ),
        );
        when(
          () => authRepo.clearStoredToken(kShiftLineId),
        ).thenAnswer((_) async {});
        final container = _container(scanRepo: scanRepo, authRepo: authRepo);

        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('777000000001');

        verify(() => authRepo.clearStoredToken(kShiftLineId)).called(1);
      },
    );

    test(
      'SHIFT_LINE_NOT_ACTIVE also routes through registry.notifySessionLost',
      () async {
        final scanRepo = _MockScanRepo();
        final authRepo = _MockAuthRepo();
        when(
          () => scanRepo.mountRoll(
            shiftLineId: kShiftLineId,
            generatedRollId: '777000000001',
          ),
        ).thenAnswer(
          (_) async => const RollScanFailure(
            BusinessFailure(code: ErrorCode.thermoformingShiftLineNotActive),
          ),
        );
        when(
          () => authRepo.clearStoredToken(kShiftLineId),
        ).thenAnswer((_) async {});
        final container = _container(scanRepo: scanRepo, authRepo: authRepo);

        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('777000000001');

        verify(() => authRepo.clearStoredToken(kShiftLineId)).called(1);
      },
    );

    test(
      'REGRESSION: AUTH_INVALID_CREDENTIALS does NOT trigger '
      'registry.notifySessionLost — a bad device key is not a session loss',
      () async {
        final scanRepo = _MockScanRepo();
        final authRepo = _MockAuthRepo();
        when(
          () => scanRepo.mountRoll(
            shiftLineId: kShiftLineId,
            generatedRollId: '777000000001',
          ),
        ).thenAnswer(
          (_) async => const RollScanFailure(
            BusinessFailure(
              code: ErrorCode.authInvalidCredentials,
              statusCode: 401,
            ),
          ),
        );
        when(
          () => authRepo.clearStoredToken(any<int>()),
        ).thenAnswer((_) async {});
        final container = _container(scanRepo: scanRepo, authRepo: authRepo);

        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('777000000001');

        final state = container.read(rollScanControllerProvider(kShiftLineId));
        // The failure still surfaces inline so the worker sees the device
        // message — it just must not bounce them to the PIN screen.
        expect(state, isA<RollScanFailureState>());
        expect(
          ((state as RollScanFailureState).failure as BusinessFailure).code,
          ErrorCode.authInvalidCredentials,
        );
        verifyNever(() => authRepo.clearStoredToken(any<int>()));
      },
    );

    test(
      'ROLL_OP_SESSION_TOKEN_MISSING routes through registry.notifySessionLost',
      () async {
        final scanRepo = _MockScanRepo();
        final authRepo = _MockAuthRepo();
        when(
          () => scanRepo.mountRoll(
            shiftLineId: kShiftLineId,
            generatedRollId: '777000000001',
          ),
        ).thenAnswer(
          (_) async => const RollScanFailure(
            BusinessFailure(
              code: ErrorCode.rollOpSessionTokenMissing,
              statusCode: 400,
            ),
          ),
        );
        when(
          () => authRepo.clearStoredToken(kShiftLineId),
        ).thenAnswer((_) async {});
        final container = _container(scanRepo: scanRepo, authRepo: authRepo);

        await container
            .read(rollScanControllerProvider(kShiftLineId).notifier)
            .mountRoll('777000000001');

        verify(() => authRepo.clearStoredToken(kShiftLineId)).called(1);
      },
    );

    test('clearError restores previously-mounted state when present', () async {
      final scanRepo = _MockScanRepo();
      when(
        () => scanRepo.mountRoll(
          shiftLineId: kShiftLineId,
          generatedRollId: '777000000001',
        ),
      ).thenAnswer((_) async => RollScanSuccess(_mounted()));
      when(
        () => scanRepo.mountRoll(
          shiftLineId: kShiftLineId,
          generatedRollId: '777000000099',
        ),
      ).thenAnswer(
        (_) async =>
            const RollScanFailure(BusinessFailure(code: ErrorCode.rollBlocked)),
      );
      final container = _container(scanRepo: scanRepo);

      await container
          .read(rollScanControllerProvider(kShiftLineId).notifier)
          .mountRoll('777000000001');
      await container
          .read(rollScanControllerProvider(kShiftLineId).notifier)
          .mountRoll('777000000099');

      expect(
        container.read(rollScanControllerProvider(kShiftLineId)),
        isA<RollScanFailureState>(),
      );

      container
          .read(rollScanControllerProvider(kShiftLineId).notifier)
          .clearError();

      expect(
        container.read(rollScanControllerProvider(kShiftLineId)),
        isA<RollScanMounted>(),
      );
    });

    group(
      'PR A — preserve mount + scan CTA on each failed-mount error code',
      () {
        const Map<String, ErrorCode> codes = <String, ErrorCode>{
          'rollTypeNotAllowedForProduct':
              ErrorCode.rollTypeNotAllowedForProduct,
          'rollAlreadyConsumed': ErrorCode.rollAlreadyConsumed,
          'rollSentToGrindingNotReusable':
              ErrorCode.rollSentToGrindingNotReusable,
          'rollNotFound': ErrorCode.rollNotFound,
          'productionPlanItemRequired': ErrorCode.productionPlanItemRequired,
          'rollReconciledOutOfStock': ErrorCode.rollReconciledOutOfStock,
        };

        for (final MapEntry<String, ErrorCode> entry in codes.entries) {
          test(
            '${entry.key} → FailureState, previous mount preserved, '
            'token NOT cleared',
            () async {
              final scanRepo = _MockScanRepo();
              final authRepo = _MockAuthRepo();
              when(
                () => scanRepo.mountRoll(
                  shiftLineId: kShiftLineId,
                  generatedRollId: '777000000001',
                ),
              ).thenAnswer((_) async => RollScanSuccess(_mounted()));
              when(
                () => scanRepo.mountRoll(
                  shiftLineId: kShiftLineId,
                  generatedRollId: '777000000099',
                ),
              ).thenAnswer(
                (_) async => RollScanFailure(
                  BusinessFailure(code: entry.value),
                ),
              );
              final container =
                  _container(scanRepo: scanRepo, authRepo: authRepo);

              // Mount the first roll so there's a `previous` to preserve.
              await container
                  .read(rollScanControllerProvider(kShiftLineId).notifier)
                  .mountRoll('777000000001');
              // Now fail the second scan.
              await container
                  .read(rollScanControllerProvider(kShiftLineId).notifier)
                  .mountRoll('777000000099');

              final state =
                  container.read(rollScanControllerProvider(kShiftLineId));
              expect(state, isA<RollScanFailureState>());
              final failureState = state as RollScanFailureState;
              // Previous mount is preserved — the home screen can keep
              // rendering the mounted-roll card, and `_showThumbZoneScan`
              // logic stays consistent (CTA visible when no current mount).
              expect(failureState.previous?.generatedRollId, '777000000001');
              expect(
                (failureState.failure as BusinessFailure).code,
                entry.value,
              );
              // None of these codes are session/line cascades — the auth
              // repo must NOT have its token cleared.
              verifyNever(() => authRepo.clearStoredToken(any<int>()));
            },
          );
        }

        test(
          'rollWorkerSessionRequired → FailureState AND token cleared',
          () async {
            final scanRepo = _MockScanRepo();
            final authRepo = _MockAuthRepo();
            when(
              () => scanRepo.mountRoll(
                shiftLineId: kShiftLineId,
                generatedRollId: '777000000001',
              ),
            ).thenAnswer(
              (_) async => const RollScanFailure(
                BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
              ),
            );
            when(
              () => authRepo.clearStoredToken(kShiftLineId),
            ).thenAnswer((_) async {});
            final container =
                _container(scanRepo: scanRepo, authRepo: authRepo);

            await container
                .read(rollScanControllerProvider(kShiftLineId).notifier)
                .mountRoll('777000000001');

            final state =
                container.read(rollScanControllerProvider(kShiftLineId));
            expect(state, isA<RollScanFailureState>());
            expect(
              ((state as RollScanFailureState).failure as BusinessFailure)
                  .code,
              ErrorCode.rollWorkerSessionRequired,
            );
            // SESSION_REQUIRED cascades through the registry so the lost
            // line drops out of /sessions/me and the picker re-opens.
            verify(() => authRepo.clearStoredToken(kShiftLineId)).called(1);
          },
        );
      },
    );

    test('reset moves state to Idle (used on logout)', () async {
      final scanRepo = _MockScanRepo();
      when(
        () => scanRepo.mountRoll(
          shiftLineId: kShiftLineId,
          generatedRollId: '777000000001',
        ),
      ).thenAnswer((_) async => RollScanSuccess(_mounted()));
      final container = _container(scanRepo: scanRepo);

      await container
          .read(rollScanControllerProvider(kShiftLineId).notifier)
          .mountRoll('777000000001');
      container.read(rollScanControllerProvider(kShiftLineId).notifier).reset();

      expect(
        container.read(rollScanControllerProvider(kShiftLineId)),
        isA<RollScanIdle>(),
      );
    });
  });
}
