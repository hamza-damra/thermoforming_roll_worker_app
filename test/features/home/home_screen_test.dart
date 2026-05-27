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
    'idle state: shows machine title, summary card, and thumb-zone "مسح رول" CTA',
    (WidgetTester tester) async {
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      when(
        () => summaryRepo.fetchSummary(shiftLineId: kShiftLineId),
      ).thenAnswer((_) async => SummarySuccess(_summary()));

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      // App bar shows machine label (ماكنة أ) instead of TH code.
      expect(find.text('ماكنة أ'), findsOneWidget);
      // Summary card shows completed count.
      expect(find.text('8'), findsOneWidget);
      // "منك: 3" subline is shown when completedRollsByCurrentWorker > 0.
      expect(find.text('منك: 3'), findsOneWidget);
      // Primary scan button is visible (thumb zone).
      expect(find.text('مسح رول'), findsOneWidget);
      expect(find.text('لا يوجد رول مركّب حاليًا'), findsOneWidget);
      expect(find.text('امسح رمز QR لتركيب رول جديد'), findsOneWidget);
    },
  );

  testWidgets(
    'when backend returns a mounted roll, compact card and close button appear',
    (WidgetTester tester) async {
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

      // Compact mounted-roll card shows roll type code and generated ID.
      expect(find.textContaining('TP-1'), findsOneWidget);
      expect(find.textContaining('777000000001'), findsOneWidget);
      // Weight line.
      expect(find.textContaining('250.0'), findsOneWidget);
      // Close-roll CTA is present; product change is not offered in this app.
      expect(find.text('إغلاق الرول السابق'), findsOneWidget);
      expect(find.text('تغيير المنتج'), findsNothing);
      // Scan CTA is hidden when a roll is mounted.
      expect(find.text('مسح رول'), findsNothing);
    },
  );

  testWidgets(
    'no active operator: shows the waiting card and hides the scan CTA',
    (WidgetTester tester) async {
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
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
      expect(find.text(RollWorkerHomeScreen.scanRoll), findsNothing);
      expect(find.text('لا يوجد رول مركّب حاليًا'), findsNothing);
    },
  );

  testWidgets(
    'active operator present: clears the waiting card and shows roll work',
    (WidgetTester tester) async {
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      when(
        () => summaryRepo.fetchSummary(shiftLineId: kShiftLineId),
      ).thenAnswer((_) async => SummarySuccess(_summary()));

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo),
      );
      await tester.pumpAndSettle();

      expect(find.text(TakeoverStrings.noActiveOperator), findsNothing);
      expect(find.text(RollWorkerHomeScreen.scanRoll), findsOneWidget);
    },
  );

  testWidgets(
    'a REST refresh that lands an active operator clears the waiting card '
    'without an app restart',
    (WidgetTester tester) async {
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
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
      expect(find.text(RollWorkerHomeScreen.scanRoll), findsNothing);

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
      expect(find.text(RollWorkerHomeScreen.scanRoll), findsOneWidget);
    },
  );
}
