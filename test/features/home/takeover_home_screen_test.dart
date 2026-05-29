import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/services/takeover_alert_service.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/line_takeover.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/controllers/shift_line_summary_controller.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/roll_worker_home_screen.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/takeover_strings.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

/// Records alerts without touching the audio/vibration plugins.
class _FakeTakeoverAlertService extends TakeoverAlertService {
  int alertCount = 0;

  @override
  Future<void> playAlert() async {
    alertCount++;
  }
}

const int kShiftLineId = 800;

/// Takeover with no expiry fields → no live countdown widget, so the screen
/// reaches a settled state for `pumpAndSettle`.
LineTakeover _takeover(TakeoverStatus status) => LineTakeover(
  status: status,
  observedAt: DateTime(2026, 5, 16, 12),
  requestId: 4321,
  requestedByOperatorName: 'سامي',
  currentOperatorName: 'خالد',
);

ShiftLineSummary _summary({LineTakeover? takeover, bool blocked = false,
    String? blockedReason}) =>
    ShiftLineSummary(
      shiftLineId: kShiftLineId,
      thermoformingLineCode: 'TH-01',
      thermoformingLineName: 'خط التشكيل 1',
      completedRollsInSession: 8,
      completedRollsByCurrentWorker: 3,
      activeOperatorName: 'مشغل التشكيل',
      blocked: blocked,
      blockedReason: blockedReason,
      takeover: takeover,
    );

Widget _wrap({
  required _MockSummaryRepo summaryRepo,
  required _MockAuthRepo authRepo,
  required _FakeTakeoverAlertService alertService,
}) {
  return ProviderScope(
    overrides: <Override>[
      shiftLineSummaryRepositoryProvider.overrideWithValue(summaryRepo),
      rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
      takeoverAlertServiceProvider.overrideWithValue(alertService),
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

void _useTallSurface(WidgetTester tester) {
  // The blocked/waiting card now sits below the operator/employee/product/
  // allowed-rolls cards (redesign), so give the ListView a tall viewport.
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'PENDING takeover plays the alert and shows the blocking dialog '
    'with no accept/reject buttons',
    (WidgetTester tester) async {
      final summaryRepo = _MockSummaryRepo();
      final authRepo = _MockAuthRepo();
      final alert = _FakeTakeoverAlertService();
      when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId))
          .thenAnswer(
        (_) async => SummarySuccess(_summary(takeover: _takeover(TakeoverStatus.pending))),
      );

      await tester.pumpWidget(
        _wrap(summaryRepo: summaryRepo, authRepo: authRepo, alertService: alert),
      );
      await tester.pumpAndSettle();

      // Blocking dialog with the acknowledge button.
      expect(find.text(TakeoverStrings.acknowledge), findsOneWidget);
      // The Roll Worker app never shows a decision.
      expect(find.text('قبول'), findsNothing);
      expect(find.text('رفض'), findsNothing);
      // Sound + vibration fired exactly once.
      expect(alert.alertCount, 1);
    },
  );

  testWidgets('acknowledging collapses the dialog into the persistent banner',
      (WidgetTester tester) async {
    final summaryRepo = _MockSummaryRepo();
    final authRepo = _MockAuthRepo();
    final alert = _FakeTakeoverAlertService();
    when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId)).thenAnswer(
      (_) async => SummarySuccess(_summary(takeover: _takeover(TakeoverStatus.pending))),
    );

    await tester.pumpWidget(
      _wrap(summaryRepo: summaryRepo, authRepo: authRepo, alertService: alert),
    );
    await tester.pumpAndSettle();
    expect(find.text(TakeoverStrings.acknowledge), findsOneWidget);

    await tester.tap(find.text(TakeoverStrings.acknowledge));
    await tester.pumpAndSettle();

    // Dialog is gone; the banner (same body text) remains.
    expect(find.text(TakeoverStrings.acknowledge), findsNothing);
    expect(find.text(TakeoverStrings.body), findsOneWidget);
  });

  testWidgets('ACCEPTED takeover shows the handover banner and no dialog',
      (WidgetTester tester) async {
    final summaryRepo = _MockSummaryRepo();
    final authRepo = _MockAuthRepo();
    final alert = _FakeTakeoverAlertService();
    when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId)).thenAnswer(
      (_) async => SummarySuccess(_summary(takeover: _takeover(TakeoverStatus.accepted))),
    );

    await tester.pumpWidget(
      _wrap(summaryRepo: summaryRepo, authRepo: authRepo, alertService: alert),
    );
    await tester.pumpAndSettle();

    expect(find.text(TakeoverStrings.acknowledge), findsNothing);
    expect(find.text(TakeoverStrings.acceptedBanner), findsOneWidget);
    expect(alert.alertCount, 0);
  });

  testWidgets('auto-released takeover blocks roll work (no scan button)',
      (WidgetTester tester) async {
    _useTallSurface(tester);
    final summaryRepo = _MockSummaryRepo();
    final authRepo = _MockAuthRepo();
    final alert = _FakeTakeoverAlertService();
    when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId)).thenAnswer(
      (_) async => SummarySuccess(
        _summary(takeover: _takeover(TakeoverStatus.timeoutAutoReleased)),
      ),
    );

    await tester.pumpWidget(
      _wrap(summaryRepo: summaryRepo, authRepo: authRepo, alertService: alert),
    );
    await tester.pumpAndSettle();

    expect(find.text(TakeoverStrings.blockedWork), findsOneWidget);
    expect(find.text(TakeoverStrings.autoReleasedBanner), findsOneWidget);
    // Scan affordance is hidden while work is blocked.
    expect(find.text(RollWorkerHomeScreen.registerRoll), findsNothing);
  });

  testWidgets('backend blocked=true shows the blocked card with its reason',
      (WidgetTester tester) async {
    _useTallSurface(tester);
    final summaryRepo = _MockSummaryRepo();
    final authRepo = _MockAuthRepo();
    final alert = _FakeTakeoverAlertService();
    when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId)).thenAnswer(
      (_) async => SummarySuccess(
        _summary(blocked: true, blockedReason: 'الخط في وضع تسليم'),
      ),
    );

    await tester.pumpWidget(
      _wrap(summaryRepo: summaryRepo, authRepo: authRepo, alertService: alert),
    );
    await tester.pumpAndSettle();

    expect(find.text('الخط في وضع تسليم'), findsOneWidget);
    expect(find.text(RollWorkerHomeScreen.registerRoll), findsNothing);
  });

  testWidgets('REJECTED takeover clears the banner and restores roll work',
      (WidgetTester tester) async {
    final summaryRepo = _MockSummaryRepo();
    final authRepo = _MockAuthRepo();
    final alert = _FakeTakeoverAlertService();
    when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId)).thenAnswer(
      (_) async => SummarySuccess(_summary(takeover: _takeover(TakeoverStatus.rejected))),
    );

    await tester.pumpWidget(
      _wrap(summaryRepo: summaryRepo, authRepo: authRepo, alertService: alert),
    );
    await tester.pumpAndSettle();

    expect(find.text(TakeoverStrings.body), findsNothing);
    expect(find.text(RollWorkerHomeScreen.registerRoll), findsOneWidget);
  });

  testWidgets('alert is not replayed when the summary refreshes for the '
      'same takeover request', (WidgetTester tester) async {
    final summaryRepo = _MockSummaryRepo();
    final authRepo = _MockAuthRepo();
    final alert = _FakeTakeoverAlertService();
    when(() => summaryRepo.fetchSummary(shiftLineId: kShiftLineId)).thenAnswer(
      (_) async => SummarySuccess(_summary(takeover: _takeover(TakeoverStatus.pending))),
    );

    await tester.pumpWidget(
      _wrap(summaryRepo: summaryRepo, authRepo: authRepo, alertService: alert),
    );
    await tester.pumpAndSettle();
    expect(alert.alertCount, 1);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(RollWorkerHomeScreen)),
    );
    await container
        .read(shiftLineSummaryControllerProvider(kShiftLineId).notifier)
        .refresh();
    await tester.pumpAndSettle();

    // Same requestId → no second alert.
    expect(alert.alertCount, 1);
  });
}
