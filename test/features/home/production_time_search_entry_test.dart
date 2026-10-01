import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/roll_worker_home_screen.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/controllers/roll_scan_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/controllers/roll_scan_state.dart';
import 'package:thermoforming_roll_worker/features/roll_search/data/roll_search_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/roll_search_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_search/presentation/controllers/roll_search_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_search/presentation/controllers/roll_search_state.dart';
import 'package:thermoforming_roll_worker/features/roll_search/presentation/screens/production_time_search_screen.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

import '../roll_search/roll_search_fakes.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = kSearchShiftLineId;

ShiftLineSummary _summary({SummaryMountedRoll? mountedRoll}) =>
    ShiftLineSummary(
      shiftLineId: kShiftLineId,
      thermoformingLineCode: 'TH-01',
      thermoformingLineName: 'خط التشكيل 1',
      completedRollsInSession: 8,
      completedRollsByCurrentWorker: 3,
      consumedWeightKgInSession: 142.5,
      rollsContributedInSession: 3,
      mountedRoll: mountedRoll,
      activeOperatorName: 'مشغل التشكيل',
    );

Future<void> _pump(
  WidgetTester tester, {
  required ShiftLineSummary summary,
  FakeRollSearchRepository? search,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final summaryRepo = _MockSummaryRepo();
  when(
    () => summaryRepo.fetchSummary(shiftLineId: kShiftLineId),
  ).thenAnswer((_) async => SummarySuccess(summary));

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        shiftLineSummaryRepositoryProvider.overrideWithValue(summaryRepo),
        rollWorkerAuthRepositoryProvider.overrideWithValue(_MockAuthRepo()),
        rollSearchRepositoryProvider.overrideWithValue(
          search ??
              FakeRollSearchRepository(<RollSearchResult>[
                RollSearchSuccess(notFoundOutcome()),
              ]),
        ),
        rollScanRepositoryProvider.overrideWithValue(
          FakeRollScanRepository(<RollScanResult>[]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const RollWorkerHomeScreen(shiftLineId: kShiftLineId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no roll mounted: «بحث بوقت الإنتاج» sits with «تركيب رول»', (
    tester,
  ) async {
    await _pump(tester, summary: _summary());
    expect(find.text(RollWorkerHomeScreen.searchByProductionTime), findsOneWidget);
    expect(find.text('بحث بوقت الإنتاج'), findsOneWidget);
    expect(find.text(RollWorkerHomeScreen.registerRoll), findsOneWidget);
    expect(find.text(RollWorkerHomeScreen.closeCurrentRoll), findsNothing);
  });

  testWidgets('a roll is mounted: the search entry is not offered', (
    tester,
  ) async {
    await _pump(
      tester,
      summary: _summary(
        mountedRoll: const SummaryMountedRoll(
          consumptionItemId: 5000,
          rollId: 1,
          generatedRollId: '777000000001',
          rollTypeCode: 'TP-1',
          rollTypeName: 'White',
          lastKnownWeightKg: 250.0,
        ),
      ),
    );
    expect(find.text(RollWorkerHomeScreen.closeCurrentRoll), findsOneWidget);
    expect(find.text('بحث بوقت الإنتاج'), findsNothing);
    expect(find.text(RollWorkerHomeScreen.registerRoll), findsNothing);
  });

  testWidgets('tapping it opens the search screen on a clean slate', (
    tester,
  ) async {
    await _pump(tester, summary: _summary());
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(RollWorkerHomeScreen)),
    );
    // Leftovers from an earlier visit: a finished search and a scan error.
    await container
        .read(rollSearchControllerProvider(kShiftLineId).notifier)
        .search(kSearchQuery);
    await container
        .read(rollScanControllerProvider(kShiftLineId).notifier)
        .mountRoll('not-12-digits');
    expect(
      container.read(rollSearchControllerProvider(kShiftLineId)),
      isA<RollSearchLoaded>(),
    );
    expect(
      container.read(rollScanControllerProvider(kShiftLineId)),
      isA<RollScanFailureState>(),
    );

    await tester.tap(find.text('بحث بوقت الإنتاج'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductionTimeSearchScreen), findsOneWidget);
    expect(
      container.read(rollSearchControllerProvider(kShiftLineId)),
      isA<RollSearchIdle>(),
    );
    expect(
      container.read(rollScanControllerProvider(kShiftLineId)),
      isNot(isA<RollScanFailureState>()),
    );
    expect(find.text('لا يوجد رول مُنتَج في هذه الدقيقة'), findsNothing);
  });
}
