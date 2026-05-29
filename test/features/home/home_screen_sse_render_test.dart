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
import 'package:thermoforming_roll_worker/features/sessions_me/data/dto/roll_worker_me_response.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/domain/entities/roll_worker_me.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_controller.dart';
import 'package:thermoforming_roll_worker/features/sessions_me/presentation/controllers/sessions_me_state.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

/// Fake [SessionsMeController] that holds a fixed state — the home screen
/// reads from `sessionsMeControllerProvider` to render the active-product
/// chip (post-migration source of truth).
class _FakeSessionsMe extends SessionsMeController {
  _FakeSessionsMe(this._initial);

  final SessionsMeState _initial;

  @override
  SessionsMeState build() => _initial;
}

/// Builds a single-line [RollWorkerMe] with the given product fields via the
/// DTO factory — avoids constructing the 24-field `RollWorkerActiveLine`
/// directly in tests.
RollWorkerMe _meWithProduct({
  required int shiftLineId,
  required int? productId,
  required String? productName,
}) {
  return RollWorkerMeResponse.fromEnvelopeData(<String, dynamic>{
    'rollWorkerOperatorId': 7,
    'rollWorkerName': 'x',
    'lines': <Map<String, dynamic>>[
      <String, dynamic>{
        'sessionId': 1,
        'shiftLineId': shiftLineId,
        'currentPlanItemProductTypeId': productId,
        'currentPlanItemProductName': productName,
        'lineLifecycleStatus': 'ACTIVE',
      },
    ],
  });
}

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

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

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
  ShiftLineSummaryRepository repo, {
  SessionsMeState? sessionsMe,
}) {
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
      if (sessionsMe != null)
        sessionsMeControllerProvider.overrideWith(
          () => _FakeSessionsMe(sessionsMe),
        ),
    ],
  );
}

void main() {
  testWidgets(
    'home renders ActiveProductChip from /sessions/me '
    'currentPlanItemProductName',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      final repo = _MockSummaryRepo();
      final container = _makeContainer(
        const ShiftLineSummary(
          shiftLineId: _kShiftLineId,
          thermoformingLineCode: 'TH-01',
          thermoformingLineName: 'خط التشكيل 1',
          completedRollsInSession: 5,
          completedRollsByCurrentWorker: 2,
          activeOperatorName: 'مشغل التشكيل',
          mountedRoll: _mounted,
        ),
        repo,
        sessionsMe: SessionsMeLoaded(
          me: _meWithProduct(
            shiftLineId: _kShiftLineId,
            productId: 6,
            productName: 'Blue 10kg',
          ),
          fetchedAt: DateTime(2026, 5, 23),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      expect(find.text('Blue 10kg'), findsWidgets);
      expect(find.text('المنتج الحالي'), findsOneWidget);
    },
  );

  testWidgets(
    'home renders the neutral placeholder chip when /sessions/me has no '
    'active plan-item product',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      final repo = _MockSummaryRepo();
      final container = _makeContainer(
        const ShiftLineSummary(
          shiftLineId: _kShiftLineId,
          thermoformingLineCode: 'TH-01',
          thermoformingLineName: 'خط التشكيل 1',
          completedRollsInSession: 5,
          completedRollsByCurrentWorker: 2,
          activeOperatorName: 'مشغل التشكيل',
          mountedRoll: _mounted,
        ),
        repo,
        sessionsMe: SessionsMeLoaded(
          me: _meWithProduct(
            shiftLineId: _kShiftLineId,
            productId: null,
            productName: null,
          ),
          fetchedAt: DateTime(2026, 5, 23),
        ),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد منتج حالي'), findsOneWidget);
      expect(find.text('المنتج الحالي'), findsOneWidget);
    },
  );

  testWidgets(
    'applying ROLL_RETURNED_REMAINING surfaces the post-incompatible-switch card',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      final repo = _MockSummaryRepo();
      final container = _makeContainer(
        const ShiftLineSummary(
          shiftLineId: _kShiftLineId,
          thermoformingLineCode: 'TH-01',
          thermoformingLineName: 'خط التشكيل 1',
          completedRollsInSession: 5,
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
      // Mounted card disappears — the mount was cleared. The roll *type* code
      // only renders inside the mounted card (the returned-remaining card
      // shows product names, not the roll type), so its absence is precise.
      expect(find.textContaining('TP-1'), findsNothing);
    },
  );

  testWidgets(
    'applying PRODUCT_CHANGED no longer drives the chip — chip source is '
    '/sessions/me only (post-migration)',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      final repo = _MockSummaryRepo();
      final container = _makeContainer(
        const ShiftLineSummary(
          shiftLineId: _kShiftLineId,
          thermoformingLineCode: 'TH-01',
          thermoformingLineName: 'خط التشكيل 1',
          completedRollsInSession: 5,
          completedRollsByCurrentWorker: 2,
          activeOperatorName: 'مشغل التشكيل',
          mountedRoll: _mounted,
        ),
        repo,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrap(container));
      await tester.pumpAndSettle();

      // Chip falls back to the placeholder because /sessions/me is idle.
      expect(find.text('لا يوجد منتج حالي'), findsOneWidget);

      // The legacy SSE applier still mutates summary state but the chip
      // is decoupled from it.
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

      // Chip stayed on the placeholder — Blue 10kg never appears via SSE.
      expect(find.text('لا يوجد منتج حالي'), findsOneWidget);
      expect(find.text('Blue 10kg'), findsNothing);
      // Mount intact.
      expect(find.textContaining('777000000001'), findsOneWidget);
    },
  );
}
