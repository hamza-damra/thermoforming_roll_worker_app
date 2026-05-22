import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/controllers/shift_line_summary_controller.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/roll_worker_home_screen.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/domain/entities/operator_dashboard_event.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/presentation/controllers/operator_dashboard_sync_controller.dart';
import 'package:thermoforming_roll_worker/features/operator_dashboard_sse/presentation/controllers/operator_dashboard_sync_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

/// No-op SSE controller — the home screen calls `start()` on it from
/// initState; we want to short-circuit the real SSE subscription so the
/// widget test can drive state updates manually via the summary
/// controller and assert the rendered output.
class _NoopSync extends OperatorDashboardSyncController {
  @override
  OperatorDashboardSyncState build(int arg) =>
      const OperatorDashboardSyncState.idle();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void onAppResumed() {}

  @override
  void onAppPaused() {}
}

const int _kShiftLineId = 800;
const SummaryMountedRoll _mounted = SummaryMountedRoll(
  consumptionItemId: 5000,
  rollId: 999,
  generatedRollId: '777000000001',
  rollTypeCode: 'TP-1',
  rollTypeName: 'White',
  lastKnownWeightKg: 100.0,
);

Widget _wrap(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const RollWorkerHomeScreen(shiftLineId: _kShiftLineId),
    ),
  );
}

ProviderContainer _makeContainer(
  ShiftLineSummary initialSummary,
  ShiftLineSummaryRepository repo,
) {
  final authRepo = _MockAuthRepo();
  when(() => authRepo.clearStoredToken(any())).thenAnswer((_) async {});
  when(
    () => repo.fetchSummary(shiftLineId: _kShiftLineId),
  ).thenAnswer((_) async => SummarySuccess(initialSummary));
  return ProviderContainer(
    overrides: <Override>[
      shiftLineSummaryRepositoryProvider.overrideWithValue(repo),
      rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
      operatorDashboardSyncControllerProvider.overrideWith(_NoopSync.new),
    ],
  );
}

void main() {
  testWidgets(
    'home renders ActiveProductChip when summary has an active product',
    (WidgetTester tester) async {
      final repo = _MockSummaryRepo();
      final container = _makeContainer(
        const ShiftLineSummary(
          shiftLineId: _kShiftLineId,
          thermoformingLineCode: 'TH-01',
          thermoformingLineName: 'خط التشكيل 1',
          completedRollsInShift: 5,
          completedRollsByCurrentWorker: 2,
          activeOperatorName: 'مشغل التشكيل',
          mountedRoll: _mounted,
          activeProduct: SummaryActiveProduct(productId: 6, name: 'Blue 10kg'),
        ),
        repo,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      expect(find.text('Blue 10kg'), findsWidgets);
      expect(find.text('المنتج الحالي'), findsOneWidget);
    },
  );

  testWidgets(
    'applying ROLL_RETURNED_REMAINING surfaces the post-incompatible-switch card',
    (WidgetTester tester) async {
      final repo = _MockSummaryRepo();
      final container = _makeContainer(
        const ShiftLineSummary(
          shiftLineId: _kShiftLineId,
          thermoformingLineCode: 'TH-01',
          thermoformingLineName: 'خط التشكيل 1',
          completedRollsInShift: 5,
          completedRollsByCurrentWorker: 2,
          activeOperatorName: 'مشغل التشكيل',
          mountedRoll: _mounted,
        ),
        repo,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      // Operator-side incompatible switch lands.
      container
          .read(shiftLineSummaryControllerProvider(_kShiftLineId).notifier)
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
      await tester.pump();

      // Returned-remaining card visible.
      expect(find.text('تم إرجاع المتبقي بواسطة المشغل'), findsOneWidget);
      // Reprint affordance is present because canPrintLabel == true.
      expect(find.text('إعادة طباعة الليبل'), findsOneWidget);
      // Mounted card disappears — the mount was cleared.
      expect(find.text('TP-1  •  777000000001'), findsNothing);
    },
  );

  testWidgets(
    'applying PRODUCT_CHANGED updates the chip without forcing a remount',
    (WidgetTester tester) async {
      final repo = _MockSummaryRepo();
      final container = _makeContainer(
        const ShiftLineSummary(
          shiftLineId: _kShiftLineId,
          thermoformingLineCode: 'TH-01',
          thermoformingLineName: 'خط التشكيل 1',
          completedRollsInShift: 5,
          completedRollsByCurrentWorker: 2,
          activeOperatorName: 'مشغل التشكيل',
          mountedRoll: _mounted,
        ),
        repo,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      // Initially no active-product chip.
      expect(find.text('المنتج الحالي'), findsNothing);

      container
          .read(shiftLineSummaryControllerProvider(_kShiftLineId).notifier)
          .applyProductChanged(
            const ProductChangedPayload(
              machineId: 10,
              newProductId: 6,
              newProductName: 'Blue 10kg',
            ),
          );
      await tester.pump();

      expect(find.text('المنتج الحالي'), findsOneWidget);
      expect(find.text('Blue 10kg'), findsWidgets);
      // Mount intact.
      expect(find.text('TP-1  •  777000000001'), findsOneWidget);
    },
  );
}
