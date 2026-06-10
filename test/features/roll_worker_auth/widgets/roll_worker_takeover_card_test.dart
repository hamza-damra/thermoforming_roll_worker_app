import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/theme/app_colors.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/dto/roll_worker_takeover_request.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_takeover.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/takeover_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/widgets/roll_worker_takeover_card.dart';

class _MockTakeoverRepo extends Mock implements TakeoverRepository {}

const int kShiftLineId = 80;

const RollWorkerTakeoverRequiredDetails _details =
    RollWorkerTakeoverRequiredDetails(
  shiftLineId: kShiftLineId,
  previousWorkerName: 'محمد سنتريسي',
  previousWorkerOperatorId: 99,
  lastKnownWeightKg: 100.0,
  generatedRollId: '777000000001',
);

Widget _harness({
  required TakeoverRepository takeover,
  VoidCallback? onCancel,
}) {
  return ProviderScope(
    overrides: <Override>[
      takeoverRepositoryProvider.overrideWithValue(takeover),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: RollWorkerTakeoverCard(
          shiftLineId: kShiftLineId,
          accentColor: AppColors.primary,
          details: _details,
          pin: '1234',
          onCancel: onCancel ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const RollWorkerTakeoverRequest(
        shiftLineId: kShiftLineId,
        incomingOperatorPin: '0000',
        action: RollWorkerTakeoverAction.fullConsumptionAndClose,
        clientRequestId: 'fallback',
      ),
    );
  });

  testWidgets('renders previous worker, weight context, credit note, 2 options',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(takeover: _MockTakeoverRepo()));
    await tester.pumpAndSettle();

    expect(
      find.text('يوجد رول مركب لم يتم إنزاله من: محمد سنتريسي'),
      findsOneWidget,
    );
    expect(find.text('الرجاء تحديد حالة الرول الحالية'), findsOneWidget);
    expect(
      find.text('الوزن المستهلك سيُحتسب للموظف السابق، وليس لك.'),
      findsOneWidget,
    );
    expect(find.textContaining('الوزن المسجّل: 100.000 كغ'), findsOneWidget);
    expect(find.text('استهلاك كامل وإنزال الرول'), findsOneWidget);
    expect(find.text('الرول ما زال مركب'), findsOneWidget);
    // No weight field until "remains mounted" is chosen.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('"الرول ما زال مركب" reveals the weight prompt', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_harness(takeover: _MockTakeoverRepo()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الرول ما زال مركب'));
    await tester.pumpAndSettle();

    expect(
      find.text('أدخل الوزن الحالي الموجود فعلياً على الرول'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('weight above lastKnownWeightKg is rejected locally', (
    WidgetTester tester,
  ) async {
    final takeover = _MockTakeoverRepo();
    await tester.pumpWidget(_harness(takeover: takeover));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الرول ما زال مركب'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '150');
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();

    expect(
      find.text('لا يمكن أن يكون الوزن أكبر من آخر وزن معروف للرول.'),
      findsOneWidget,
    );
    verifyNever(() => takeover.takeover(any()));
  });

  testWidgets('"استهلاك كامل" submits FULL_CONSUMPTION_AND_CLOSE (no weight)', (
    WidgetTester tester,
  ) async {
    final takeover = _MockTakeoverRepo();
    when(() => takeover.takeover(any()))
        .thenAnswer((_) async => const TakeoverFailure(NetworkFailure()));

    await tester.pumpWidget(_harness(takeover: takeover));
    await tester.pumpAndSettle();

    await tester.tap(find.text('استهلاك كامل وإنزال الرول'));
    await tester.pumpAndSettle();

    final List<dynamic> captured =
        verify(() => takeover.takeover(captureAny())).captured;
    expect(captured, hasLength(1));
    final RollWorkerTakeoverRequest req =
        captured.single as RollWorkerTakeoverRequest;
    expect(req.action, RollWorkerTakeoverAction.fullConsumptionAndClose);
    expect(req.currentWeightKg, isNull);
    expect(req.incomingOperatorPin, '1234');
    expect(req.clientRequestId, isNotEmpty);
  });

  testWidgets('cancel invokes the onCancel callback', (
    WidgetTester tester,
  ) async {
    bool cancelled = false;
    await tester.pumpWidget(
      _harness(takeover: _MockTakeoverRepo(), onCancel: () => cancelled = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
  });
}
