import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/controllers/shift_line_summary_controller.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/roll_worker_home_screen.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/takeover_strings.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

ShiftLineSummary _summary({
  SummaryMountedRoll? mountedRoll,
  String? activeOperatorName = 'مشغل التشكيل',
}) => ShiftLineSummary(
  shiftLineId: kShiftLineId,
  thermoformingLineCode: 'TH-01',
  thermoformingLineName: 'خط التشكيل 1',
  completedRollsInSession: 8,
  completedRollsByCurrentWorker: 3,
  mountedRoll: mountedRoll,
  activeOperatorName: activeOperatorName,
);

void _useTallSurface(WidgetTester tester) {
  // The redesigned dashboard stacks many cards; give the ListView a large
  // viewport so the lower-priority summary/consumed sections are laid out.
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap({
  required _MockSummaryRepo summaryRepo,
  required _MockAuthRepo authRepo,
}) {
  return ProviderScope(
    overrides: <Override>[
      shiftLineSummaryRepositoryProvider.overrideWithValue(summaryRepo),
      rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const RollWorkerHomeScreen(shiftLineId: kShiftLineId),
    ),
  );
}

void main() {
  testWidgets(
    'idle state: shows machine title, summary card, and fixed "تركيب رول" CTA',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      when(
        () => summaryRepo.fetchSummary(shiftLineId: kShiftLineId),
      ).thenAnswer((_) async => SummarySuccess(_summary()));

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      // App bar shows line label (خط أ) instead of TH code or machine label.
      expect(find.text('خط أ'), findsOneWidget);
      // V109 summary card: session-scoped closed-rolls count + action subtitle
      // (never a fabricated per-worker kg or "منك" personal attribution).
      expect(find.text('8'), findsOneWidget);
      expect(
        find.text('الرولات التي تم إغلاقها في هذه الجلسة'),
        findsOneWidget,
      );
      expect(find.textContaining('منك'), findsNothing);
      expect(find.textContaining('كغ'), findsNothing);
      // Fixed register CTA is visible when no roll is mounted.
      expect(find.text(RollWorkerHomeScreen.registerRoll), findsOneWidget);
      // Empty mounted-roll card (message + helper).
      expect(find.text('لا يوجد رول مركب حالياً'), findsOneWidget);
      expect(find.text('اضغط تركيب رول لبدء رول جديد'), findsOneWidget);
    },
  );

  testWidgets(
    'when backend returns a mounted roll, compact card and close button appear',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();

      const SummaryMountedRoll mountedRoll = SummaryMountedRoll(
        consumptionItemId: 5000,
        rollId: 1,
        generatedRollId: '777000000001',
        rollTypeCode: 'TP-1',
        rollTypeName: 'White',
        lastKnownWeightKg: 250.0,
      );
      when(
        () => summaryRepo.fetchSummary(shiftLineId: kShiftLineId),
      ).thenAnswer(
        (_) async => SummarySuccess(_summary(mountedRoll: mountedRoll)),
      );

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      // Compact mounted-roll card shows the serial plus the read-only latest
      // known weight; the roll type stays hidden (identified by serial only).
      expect(find.textContaining('777000000001'), findsOneWidget);
      expect(find.text('الرول المركب حالياً'), findsOneWidget);
      expect(find.text('قيد الاستهلاك'), findsOneWidget);
      // Latest-known weight row is shown (read-only, 3 decimals + كغ).
      expect(find.text('آخر وزن معروف'), findsOneWidget);
      expect(find.text('250.000 كغ'), findsOneWidget);
      // Roll type is still not shown on the mounted card.
      expect(find.textContaining('TP-1'), findsNothing);
      // Close-roll CTA is the fixed bottom action when a roll is mounted.
      expect(find.text(RollWorkerHomeScreen.closeCurrentRoll), findsOneWidget);
      expect(find.text('تغيير المنتج'), findsNothing);
      // Register CTA is hidden when a roll is mounted (state-driven button).
      expect(find.text(RollWorkerHomeScreen.registerRoll), findsNothing);
    },
  );

  testWidgets(
    'no active operator: shows the waiting card and hides the scan CTA',
    (WidgetTester tester) async {
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      _useTallSurface(tester);
      when(
        () => summaryRepo.fetchSummary(shiftLineId: kShiftLineId),
      ).thenAnswer(
        (_) async => SummarySuccess(_summary(activeOperatorName: null)),
      );

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      // Waiting/unavailable card replaces the mount section.
      expect(find.text(TakeoverStrings.noActiveOperator), findsOneWidget);
      // Roll work is not offered while no operator owns the line.
      expect(find.text(RollWorkerHomeScreen.registerRoll), findsNothing);
      expect(find.text('لا يوجد رول مركب حالياً'), findsNothing);
    },
  );

  testWidgets(
    'active operator present: clears the waiting card and shows roll work',
    (WidgetTester tester) async {
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      _useTallSurface(tester);
      when(
        () => summaryRepo.fetchSummary(shiftLineId: kShiftLineId),
      ).thenAnswer((_) async => SummarySuccess(_summary()));

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text(TakeoverStrings.noActiveOperator), findsNothing);
      expect(find.text(RollWorkerHomeScreen.registerRoll), findsOneWidget);
    },
  );

  testWidgets(
    'a REST refresh that lands an active operator clears the waiting card '
    'without an app restart',
    (WidgetTester tester) async {
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      _useTallSurface(tester);
      // First fetch: line is waiting. Second fetch (the adaptive refresh):
      // a thermoforming operator now owns the line.
      int calls = 0;
      when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId)).thenAnswer(
        (_) async {
          calls++;
          return SummarySuccess(
            calls == 1 ? _summary(activeOperatorName: null) : _summary(),
          );
        },
      );

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      // Waiting card is shown, roll work is suppressed.
      expect(find.text(TakeoverStrings.noActiveOperator), findsOneWidget);
      expect(find.text(RollWorkerHomeScreen.registerRoll), findsNothing);

      // The next REST summary (e.g. driven by an SSE LINE_STATE_CHANGED) says
      // an operator is active — the UI must converge from REST alone.
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(RollWorkerHomeScreen)),
      );
      await container
          .read(shiftLineSummaryControllerProvider(kShiftLineId).notifier)
          .refresh();
      await tester.pumpAndSettle();

      expect(find.text(TakeoverStrings.noActiveOperator), findsNothing);
      expect(find.text(RollWorkerHomeScreen.registerRoll), findsOneWidget);
    },
  );

  testWidgets(
    'pull-to-refresh re-fetches the line summary',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      int calls = 0;
      when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId))
          .thenAnswer((_) async {
        calls++;
        return SummarySuccess(_summary());
      });

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo),
      );
      await tester.pumpAndSettle();
      expect(calls, 1); // initial load

      // Trigger the pull-to-refresh programmatically (deterministic — a fling
      // gesture is flaky against short content). This invokes the same
      // onRefresh wiring a real pull does.
      final RefreshIndicatorState refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator));
      unawaited(refresh.show());
      await tester.pumpAndSettle();

      // The pull triggered another summary fetch.
      expect(calls, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'pull-to-refresh failure surfaces the failure snackbar',
    (WidgetTester tester) async {
      _useTallSurface(tester);
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      int calls = 0;
      when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId))
          .thenAnswer((_) async {
        calls++;
        // First load succeeds (data on screen); the pull refresh fails.
        if (calls == 1) return SummarySuccess(_summary());
        return const SummaryFailure(NetworkFailure());
      });

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      final RefreshIndicatorState refresh = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator));
      unawaited(refresh.show());
      await tester.pumpAndSettle();

      // Data is kept (no error screen) but the failure is surfaced.
      expect(find.text(RollWorkerHomeScreen.refreshFailed), findsOneWidget);
    },
  );
}
