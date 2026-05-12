import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/roll_worker_home_screen.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

ShiftLineSummary _summary({SummaryMountedRoll? mountedRoll}) =>
    ShiftLineSummary(
      shiftLineId: kShiftLineId,
      thermoformingLineCode: 'TH-01',
      thermoformingLineName: 'خط التشكيل 1',
      completedRollsInShift: 8,
      completedRollsByCurrentWorker: 3,
      mountedRoll: mountedRoll,
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
    'idle state: shows line header, summary card, and "مسح رول" CTA',
    (WidgetTester tester) async {
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      when(
        () => summaryRepo.fetchSummary(shiftLineId: kShiftLineId),
      ).thenAnswer((_) async => SummarySuccess(_summary()));

      await tester.pumpWidget(_wrap(summaryRepo: summaryRepo, authRepo: authRepo));
      await tester.pumpAndSettle();

      // Compact line header shows the line code from backend.
      expect(find.text('TH-01'), findsOneWidget);
      // Summary card shows completed count.
      expect(find.text('8'), findsOneWidget);
      // "منك: 3" subline is shown when completedRollsByCurrentWorker > 0.
      expect(find.text('منك: 3'), findsOneWidget);
      // Primary scan button is visible.
      expect(find.text('مسح رول'), findsOneWidget);
      // Empty mount heading is present.
      expect(find.text('لا يوجد رول مركّب حاليًا'), findsOneWidget);
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
      ).thenAnswer((_) async => SummarySuccess(_summary(mountedRoll: mountedRoll)));

      await tester.pumpWidget(_wrap(summaryRepo: summaryRepo, authRepo: authRepo));
      await tester.pumpAndSettle();

      // Compact mounted-roll card shows roll type code and generated ID.
      expect(find.textContaining('TP-1'), findsOneWidget);
      expect(find.textContaining('777000000001'), findsOneWidget);
      // Weight line.
      expect(find.textContaining('250.0'), findsOneWidget);
      // Close and product-switch CTAs are present.
      expect(find.text('إغلاق الرول السابق'), findsOneWidget);
      expect(find.text('تغيير المنتج'), findsOneWidget);
      // Scan CTA is hidden when a roll is mounted.
      expect(find.text('مسح رول'), findsNothing);
    },
  );

  testWidgets(
    'tapping "تغيير المنتج" routes to the product-switch blocked screen',
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
      ).thenAnswer((_) async => SummarySuccess(_summary(mountedRoll: mountedRoll)));

      await tester.pumpWidget(_wrap(summaryRepo: summaryRepo, authRepo: authRepo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('تغيير المنتج'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تغيير المنتج'));
      await tester.pumpAndSettle();

      // Blocked-screen content is visible.
      expect(find.text('تغيير المنتج غير متاح حاليًا'), findsOneWidget);
      expect(
        find.text(
          'بانتظار دعم الخادم لعرض المنتجات المتوافقة مع الرول الحالي.',
        ),
        findsOneWidget,
      );
    },
  );
}
