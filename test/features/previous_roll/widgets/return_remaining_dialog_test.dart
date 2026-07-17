import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/data/previous_roll_providers.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/entities/previous_roll_resolution.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/domain/previous_roll_repository.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/widgets/reason_text_field.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/widgets/remaining_weight_field.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/widgets/return_remaining_dialog.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockPrevRepo extends Mock implements PreviousRollRepository {}

class _MockScanRepo extends Mock implements RollScanRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;
const String kReason = 'تبقّى وزن صالح للإرجاع';

PreviousRollResolution _resolution() => const PreviousRollResolution(
  rollId: 1,
  generatedRollId: '777000000001',
  finalState: PreviousRollFinalState.partiallyReturned,
  consumedWeightKg: 175.5,
  remainingWeightKg: 75.5,
  remainderAction: PreviousRollRemainderAction.returned,
  eventType: PreviousRollEventType.closedPartialReturn,
  reprintAvailable: true,
);

Finder _weightField() => find.descendant(
  of: find.byType(RemainingWeightField),
  matching: find.byType(TextField),
);

Finder _reasonField() => find.descendant(
  of: find.byType(ReasonTextField),
  matching: find.byType(TextField),
);

Widget _harness({
  required GlobalKey<NavigatorState> navKey,
  required _MockPrevRepo prev,
  required _MockScanRepo scan,
  required _MockAuthRepo auth,
}) {
  return ProviderScope(
    overrides: <Override>[
      previousRollRepositoryProvider.overrideWithValue(prev),
      rollScanRepositoryProvider.overrideWithValue(scan),
      rollWorkerAuthRepositoryProvider.overrideWithValue(auth),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      navigatorKey: navKey,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: SizedBox()),
    ),
  );
}

void main() {
  testWidgets('rejects values above maxAllowedKg with the prescribed Arabic', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showReturnRemainingDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
        maxAllowedKg: 250.0,
      ),
    );
    await tester.pumpAndSettle();

    // Title, body, and the reason label all render the prescribed Arabic copy.
    expect(find.text('تأكيد إرجاع المتبقي'), findsOneWidget);
    expect(
      find.text('هل تريد إرجاع الوزن المتبقي من هذا الرول؟'),
      findsOneWidget,
    );
    expect(find.text('سبب إرجاع المتبقي'), findsOneWidget);

    await tester.enterText(_weightField(), '500');
    await tester.enterText(_reasonField(), kReason);
    await tester.tap(find.text('إرجاع المتبقي'));
    await tester.pumpAndSettle();

    expect(
      find.text('لا يمكن أن يكون الوزن أكبر من آخر وزن معروف للرول.'),
      findsOneWidget,
    );
    verifyNever(
      () => prev.returnRemaining(
        shiftLineId: any<int>(named: 'shiftLineId'),
        remainingWeightKg: any<double>(named: 'remainingWeightKg'),
        reasonText: any<String>(named: 'reasonText'),
      ),
    );
  });

  testWidgets('valid weight + reason dispatches to the repository', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();
    when(
      () => prev.returnRemaining(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 75.5,
        reasonText: kReason,
      ),
    ).thenAnswer((_) async => PreviousRollSuccess(_resolution()));

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showReturnRemainingDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
        maxAllowedKg: 250.0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_weightField(), '75.5');
    await tester.enterText(_reasonField(), kReason);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرجاع المتبقي'));
    await tester.pumpAndSettle();

    verify(
      () => prev.returnRemaining(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 75.5,
        reasonText: kReason,
      ),
    ).called(1);
  });

  testWidgets('empty reason blocks submit and never dispatches', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showReturnRemainingDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
        maxAllowedKg: 250.0,
      ),
    );
    await tester.pumpAndSettle();

    // Valid weight; reason typed then cleared → "touched" but empty.
    await tester.enterText(_weightField(), '75.5');
    await tester.enterText(_reasonField(), 'x');
    await tester.enterText(_reasonField(), '');
    await tester.pumpAndSettle();

    // Empty reason surfaces the required error and keeps confirm disabled.
    expect(find.text('السبب مطلوب'), findsOneWidget);
    final ElevatedButton confirm = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'إرجاع المتبقي'),
    );
    expect(confirm.onPressed, isNull);

    await tester.tap(find.text('إرجاع المتبقي'));
    await tester.pumpAndSettle();

    verifyNever(
      () => prev.returnRemaining(
        shiftLineId: any<int>(named: 'shiftLineId'),
        remainingWeightKg: any<double>(named: 'remainingWeightKg'),
        reasonText: any<String>(named: 'reasonText'),
      ),
    );
  });

  testWidgets('whitespace-only reason is rejected (trimmed before submit)', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showReturnRemainingDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
        maxAllowedKg: 250.0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_weightField(), '75.5');
    await tester.enterText(_reasonField(), '    ');
    await tester.tap(find.text('إرجاع المتبقي'));
    await tester.pumpAndSettle();

    expect(find.text('السبب مطلوب'), findsOneWidget);
    verifyNever(
      () => prev.returnRemaining(
        shiftLineId: any<int>(named: 'shiftLineId'),
        remainingWeightKg: any<double>(named: 'remainingWeightKg'),
        reasonText: any<String>(named: 'reasonText'),
      ),
    );
  });

  testWidgets('long reason near 500 chars submits and is trimmed', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();
    final String longReason = 'سبب ${'ط' * 480}';
    when(
      () => prev.returnRemaining(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 75.5,
        reasonText: longReason.trim(),
      ),
    ).thenAnswer((_) async => PreviousRollSuccess(_resolution()));

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showReturnRemainingDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
        maxAllowedKg: 250.0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_weightField(), '75.5');
    await tester.enterText(_reasonField(), '  $longReason  ');
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرجاع المتبقي'));
    await tester.pumpAndSettle();

    verify(
      () => prev.returnRemaining(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 75.5,
        reasonText: longReason.trim(),
      ),
    ).called(1);
  });

  testWidgets('backend INVALID_REMAINING_ROLL_WEIGHT renders inline Arabic', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();
    when(
      () => prev.returnRemaining(
        shiftLineId: kShiftLineId,
        remainingWeightKg: 75.5,
        reasonText: kReason,
      ),
    ).thenAnswer(
      (_) async => const PreviousRollFailure(
        BusinessFailure(code: ErrorCode.invalidRemainingRollWeight),
      ),
    );

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showReturnRemainingDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
        maxAllowedKg: 250.0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_weightField(), '75.5');
    await tester.enterText(_reasonField(), kReason);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرجاع المتبقي'));
    await tester.pumpAndSettle();

    // Handoff §7.2 wording (replaces the in-house phrasing).
    expect(
      find.text(
        'الوزن المتبقي غير صالح. يجب أن يكون بين صفر ووزن الرول الحالي.',
      ),
      findsOneWidget,
    );
    // Typed reason is preserved after the failure so the worker can retry.
    expect(find.text(kReason), findsOneWidget);
  });

  testWidgets(
    'backend ROLL_RETURN_REASON_REQUIRED surfaces under the reason field',
    (WidgetTester tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final prev = _MockPrevRepo();
      final scan = _MockScanRepo();
      final auth = _MockAuthRepo();
      when(
        () => prev.returnRemaining(
          shiftLineId: kShiftLineId,
          remainingWeightKg: 75.5,
          reasonText: kReason,
        ),
      ).thenAnswer(
        (_) async => const PreviousRollFailure(
          BusinessFailure(code: ErrorCode.rollReturnReasonRequired),
        ),
      );

      await tester.pumpWidget(
        _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
      );
      unawaited(
        showReturnRemainingDialog(
          navKey.currentContext!,
          shiftLineId: kShiftLineId,
          maxAllowedKg: 250.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(_weightField(), '75.5');
      await tester.enterText(_reasonField(), kReason);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إرجاع المتبقي'));
      await tester.pumpAndSettle();

      expect(find.text('سبب إرجاع المتبقي مطلوب.'), findsOneWidget);
    },
  );

  testWidgets('0 is invalid: confirm stays disabled and never dispatches', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    final prev = _MockPrevRepo();
    final scan = _MockScanRepo();
    final auth = _MockAuthRepo();

    await tester.pumpWidget(
      _harness(navKey: navKey, prev: prev, scan: scan, auth: auth),
    );
    unawaited(
      showReturnRemainingDialog(
        navKey.currentContext!,
        shiftLineId: kShiftLineId,
        maxAllowedKg: 250.0,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_weightField(), '0');
    await tester.enterText(_reasonField(), kReason);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'يجب أن يكون الوزن المتبقي أكبر من 0 كغ. إذا انتهى الرول اختر استهلاك كامل.',
      ),
      findsOneWidget,
    );
    final ElevatedButton confirm = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'إرجاع المتبقي'),
    );
    expect(confirm.onPressed, isNull);

    await tester.tap(find.text('إرجاع المتبقي'));
    await tester.pumpAndSettle();
    verifyNever(
      () => prev.returnRemaining(
        shiftLineId: any<int>(named: 'shiftLineId'),
        remainingWeightKg: any<double>(named: 'remainingWeightKg'),
        reasonText: any<String>(named: 'reasonText'),
      ),
    );
  });
}

void unawaited(Future<dynamic>? future) {}
