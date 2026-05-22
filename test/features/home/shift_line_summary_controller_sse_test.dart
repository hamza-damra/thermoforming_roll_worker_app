import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/controllers/shift_line_summary_controller.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/controllers/shift_line_summary_state.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/domain/entities/operator_dashboard_event.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int _shiftLineId = 800;

const SummaryMountedRoll _mounted = SummaryMountedRoll(
  consumptionItemId: 5000,
  rollId: 999,
  generatedRollId: '777000000001',
  rollTypeCode: 'TP-1',
  rollTypeName: 'White',
  lastKnownWeightKg: 100.0,
);

ShiftLineSummary _summaryWithMount({SummaryActiveProduct? activeProduct}) =>
    ShiftLineSummary(
      shiftLineId: _shiftLineId,
      thermoformingLineCode: 'TH-01',
      thermoformingLineName: 'خط التشكيل 1',
      completedRollsInShift: 5,
      completedRollsByCurrentWorker: 2,
      mountedRoll: _mounted,
      activeProduct: activeProduct,
    );

ProviderContainer _makeContainer(ShiftLineSummaryRepository repo) {
  final authRepo = _MockAuthRepo();
  when(() => authRepo.clearStoredToken(any())).thenAnswer((_) async {});
  return ProviderContainer(
    overrides: [
      shiftLineSummaryRepositoryProvider.overrideWithValue(repo),
      rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
    ],
  );
}

Future<void> _seedLoaded(
  ProviderContainer container,
  ShiftLineSummary summary,
) async {
  final repo = container.read(shiftLineSummaryRepositoryProvider);
  when(
    () => repo.fetchSummary(shiftLineId: _shiftLineId),
  ).thenAnswer((_) async => SummarySuccess(summary));
  await container
      .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
      .load();
}

void main() {
  group('ShiftLineSummaryController SSE appliers', () {
    test('applyProductChanged updates the active product chip', () async {
      final repo = _MockSummaryRepo();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);
      await _seedLoaded(container, _summaryWithMount());

      container
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .applyProductChanged(
            const ProductChangedPayload(
              machineId: 10,
              newProductId: 6,
              newProductName: 'Blue 10kg',
            ),
          );

      final state =
          container.read(shiftLineSummaryControllerProvider(_shiftLineId))
              as SummaryLoaded;
      expect(state.summary.activeProduct?.productId, 6);
      expect(state.summary.activeProduct?.name, 'Blue 10kg');
      // The mount stays intact.
      expect(state.summary.mountedRoll, _mounted);
    });

    test('applyRollSegmentRecorded updates only the mounted roll weight, '
        'ignoring events for other roll ids', () async {
      final repo = _MockSummaryRepo();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);
      await _seedLoaded(container, _summaryWithMount());

      final ctrl = container.read(
        shiftLineSummaryControllerProvider(_shiftLineId).notifier,
      );
      ctrl.applyRollSegmentRecorded(
        const RollConsumptionSegmentRecordedPayload(
          machineId: 10,
          rollId: 999,
          productId: 5,
          productName: 'Red',
          previousWeight: 100,
          currentWeight: 70,
          consumedWeight: 30,
        ),
      );
      var state =
          container.read(shiftLineSummaryControllerProvider(_shiftLineId))
              as SummaryLoaded;
      expect(state.summary.mountedRoll?.lastKnownWeightKg, 70);

      // Event for an unrelated rollId should be ignored.
      ctrl.applyRollSegmentRecorded(
        const RollConsumptionSegmentRecordedPayload(
          machineId: 10,
          rollId: 12345,
          productId: 5,
          productName: 'Red',
          previousWeight: 70,
          currentWeight: 50,
          consumedWeight: 20,
        ),
      );
      state =
          container.read(shiftLineSummaryControllerProvider(_shiftLineId))
              as SummaryLoaded;
      expect(state.summary.mountedRoll?.lastKnownWeightKg, 70);
    });

    test('applyRollContinued keeps mount, updates weight + activeProduct, '
        'returns true', () async {
      final repo = _MockSummaryRepo();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);
      await _seedLoaded(container, _summaryWithMount());

      final ctrl = container.read(
        shiftLineSummaryControllerProvider(_shiftLineId).notifier,
      );
      final applied = ctrl.applyRollContinued(
        const RollContinuedWithNewProductPayload(
          machineId: 10,
          rollId: 999,
          rollNumber: '777000000001',
          newProductId: 6,
          newProductName: 'Blue 10kg',
          currentWeight: 70.0,
          mounted: true,
        ),
      );
      expect(applied, isTrue);

      final state =
          container.read(shiftLineSummaryControllerProvider(_shiftLineId))
              as SummaryLoaded;
      expect(state.summary.mountedRoll?.rollId, 999);
      expect(state.summary.mountedRoll?.lastKnownWeightKg, 70.0);
      expect(state.summary.activeProduct?.name, 'Blue 10kg');
    });

    test('applyRollContinued returns false when the roll id does not match — '
        'caller falls back to REST refetch', () async {
      final repo = _MockSummaryRepo();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);
      await _seedLoaded(container, _summaryWithMount());

      final applied = container
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .applyRollContinued(
            const RollContinuedWithNewProductPayload(
              machineId: 10,
              rollId: 12345,
              rollNumber: '777999999999',
              newProductId: 6,
              newProductName: 'Blue 10kg',
              currentWeight: 70.0,
              mounted: true,
            ),
          );
      expect(applied, isFalse);
    });

    test(
      'applyRollReturnedRemaining clears the mount and surfaces the banner',
      () async {
        final repo = _MockSummaryRepo();
        final container = _makeContainer(repo);
        addTearDown(container.dispose);
        await _seedLoaded(container, _summaryWithMount());

        container
            .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
            .applyRollReturnedRemaining(
              const RollReturnedRemainingPayload(
                machineId: 10,
                rollId: 999,
                rollNumber: '777000000001',
                returnedWeight: 70.0,
                canPrintLabel: true,
                mounted: false,
                oldProductName: 'Red 20kg',
                newProductId: 6,
                newProductName: 'Blue 10kg',
              ),
            );

        final state =
            container.read(shiftLineSummaryControllerProvider(_shiftLineId))
                as SummaryLoaded;
        expect(state.summary.mountedRoll, isNull);
        expect(state.summary.returnedRemainingRoll, isNotNull);
        expect(state.summary.returnedRemainingRoll!.returnedWeightKg, 70.0);
        expect(state.summary.returnedRemainingRoll!.canPrintLabel, isTrue);
        expect(state.summary.activeProduct?.productId, 6);
      },
    );

    test(
      'applyMachineRollState with no mount clears mount + sets active product',
      () async {
        final repo = _MockSummaryRepo();
        final container = _makeContainer(repo);
        addTearDown(container.dispose);
        await _seedLoaded(container, _summaryWithMount());

        final applied = container
            .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
            .applyMachineRollState(
              const MachineRollStateUpdatedPayload(
                machineId: 10,
                activeProductId: 6,
                activeProductName: 'Blue 10kg',
                lastAction: 'product_switch_roll_returned',
              ),
            );
        expect(applied, isTrue);
        final state =
            container.read(shiftLineSummaryControllerProvider(_shiftLineId))
                as SummaryLoaded;
        expect(state.summary.mountedRoll, isNull);
        expect(state.summary.activeProduct?.productId, 6);
      },
    );

    test(
      'applyMachineRollState with a mount we already know updates weight in-place',
      () async {
        final repo = _MockSummaryRepo();
        final container = _makeContainer(repo);
        addTearDown(container.dispose);
        await _seedLoaded(container, _summaryWithMount());

        final applied = container
            .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
            .applyMachineRollState(
              const MachineRollStateUpdatedPayload(
                machineId: 10,
                activeProductId: 6,
                activeProductName: 'Blue 10kg',
                mountedRollId: 999,
                mountedRollNumber: '777000000001',
                mountedRollCurrentWeight: 70.0,
                mountedRollCompatibleWithActiveProduct: true,
                lastAction: 'product_switch_roll_continued',
              ),
            );
        expect(applied, isTrue);
        final state =
            container.read(shiftLineSummaryControllerProvider(_shiftLineId))
                as SummaryLoaded;
        expect(state.summary.mountedRoll?.rollId, 999);
        expect(state.summary.mountedRoll?.lastKnownWeightKg, 70.0);
        expect(state.summary.activeProduct?.name, 'Blue 10kg');
      },
    );

    test(
      'applyMachineRollState with an unknown mount returns false → refetch',
      () async {
        final repo = _MockSummaryRepo();
        final container = _makeContainer(repo);
        addTearDown(container.dispose);
        await _seedLoaded(container, _summaryWithMount());

        final applied = container
            .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
            .applyMachineRollState(
              const MachineRollStateUpdatedPayload(
                machineId: 10,
                activeProductId: 6,
                activeProductName: 'Blue 10kg',
                mountedRollId: 555,
                mountedRollNumber: '777000005555',
                mountedRollCurrentWeight: 90.0,
              ),
            );
        expect(applied, isFalse);
      },
    );

    test(
      'acknowledgeReturnedRemaining dismisses the returned-remaining banner',
      () async {
        final repo = _MockSummaryRepo();
        final container = _makeContainer(repo);
        addTearDown(container.dispose);
        await _seedLoaded(container, _summaryWithMount());

        final ctrl = container.read(
          shiftLineSummaryControllerProvider(_shiftLineId).notifier,
        );
        ctrl.applyRollReturnedRemaining(
          const RollReturnedRemainingPayload(
            machineId: 10,
            rollId: 999,
            rollNumber: '777000000001',
            returnedWeight: 70.0,
            canPrintLabel: true,
            mounted: false,
          ),
        );
        ctrl.acknowledgeReturnedRemaining();
        final state =
            container.read(shiftLineSummaryControllerProvider(_shiftLineId))
                as SummaryLoaded;
        expect(state.summary.returnedRemainingRoll, isNull);
      },
    );

    test(
      'refresh after SSE-applied changes preserves the SSE overlays',
      () async {
        final repo = _MockSummaryRepo();
        final container = _makeContainer(repo);
        addTearDown(container.dispose);
        // Initial load — REST returns the mount, no active product (the
        // REST endpoint does not carry one today).
        when(
          () => repo.fetchSummary(shiftLineId: _shiftLineId),
        ).thenAnswer((_) async => SummarySuccess(_summaryWithMount()));
        await container
            .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
            .load();

        // SSE delivers a product change.
        container
            .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
            .applyProductChanged(
              const ProductChangedPayload(
                machineId: 10,
                newProductId: 6,
                newProductName: 'Blue 10kg',
              ),
            );

        // A REST refresh (e.g. on reconnect) lands the same REST shape; the
        // SSE-driven active-product chip must survive.
        await container
            .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
            .refresh();
        final state =
            container.read(shiftLineSummaryControllerProvider(_shiftLineId))
                as SummaryLoaded;
        expect(state.summary.activeProduct?.name, 'Blue 10kg');
      },
    );

    test('SSE appliers are no-ops while no REST snapshot has loaded yet', () {
      final repo = _MockSummaryRepo();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);
      // Don't load — state is SummaryLoading.
      final ctrl = container.read(
        shiftLineSummaryControllerProvider(_shiftLineId).notifier,
      );
      ctrl.applyProductChanged(
        const ProductChangedPayload(
          machineId: 10,
          newProductId: 6,
          newProductName: 'Blue 10kg',
        ),
      );
      // Should remain Loading — the controller never invents a summary
      // out of thin air.
      expect(
        container.read(shiftLineSummaryControllerProvider(_shiftLineId)),
        isA<SummaryLoading>(),
      );
    });
  });
}
