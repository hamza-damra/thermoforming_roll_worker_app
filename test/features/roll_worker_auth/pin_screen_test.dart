import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/screens/pin_screen.dart';

class _MockRepo extends Mock implements RollWorkerAuthRepository {}

const int kShiftLineId = 800;

Widget _wrap({required _MockRepo repo}) {
  return ProviderScope(
    overrides: <Override>[
      rollWorkerAuthRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const PinScreen(shiftLineId: kShiftLineId),
    ),
  );
}

void main() {
  testWidgets('PinScreen renders the prescribed Arabic title and button', (
    WidgetTester tester,
  ) async {
    final repo = _MockRepo();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل دخول عامل الرولات'), findsWidgets);
    expect(find.text('دخول'), findsOneWidget);
  });

  testWidgets('typing a PIN and submitting calls repository.login', (
    WidgetTester tester,
  ) async {
    final repo = _MockRepo();
    when(() => repo.login(shiftLineId: kShiftLineId, pin: '1234')).thenAnswer(
      (_) async => RollWorkerAuthSuccess(
        RollWorkerSession(
          sessionId: 1,
          rollWorkerOperatorId: 1,
          rollWorkerName: 'Ahmad',
          thermoformingShiftId: 1,
          thermoformingShiftLineId: kShiftLineId,
          thermoformingLineId: 1,
          palletizingLineId: 1,
          startedAt: DateTime.parse('2026-05-08T13:00:00Z'),
        ),
      ),
    );
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    verify(() => repo.login(shiftLineId: kShiftLineId, pin: '1234')).called(1);
  });

  testWidgets(
    'ROLL_WORKER_NOT_ALLOWED surfaces an inline Arabic unauthorized error',
    (WidgetTester tester) async {
      final repo = _MockRepo();
      when(
        () => repo.login(
          shiftLineId: kShiftLineId,
          pin: any<String>(named: 'pin'),
        ),
      ).thenAnswer(
        (_) async => const RollWorkerAuthFailure(
          BusinessFailure(code: ErrorCode.rollWorkerNotAllowed),
        ),
      );
      await tester.pumpWidget(_wrap(repo: repo));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('دخول'));
      await tester.pumpAndSettle();

      expect(
        find.text('هذا الموظف غير مصرح له كتطبيق عامل الرولات'),
        findsOneWidget,
      );
    },
  );

  testWidgets('OPERATOR_PIN_INVALID surfaces the mapped Arabic error', (
    WidgetTester tester,
  ) async {
    final repo = _MockRepo();
    when(
      () => repo.login(
        shiftLineId: kShiftLineId,
        pin: any<String>(named: 'pin'),
      ),
    ).thenAnswer(
      (_) async => const RollWorkerAuthFailure(
        BusinessFailure(code: ErrorCode.operatorPinInvalid),
      ),
    );
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text('رقم تعريف غير صحيح.'), findsOneWidget);
  });

  testWidgets('empty PIN does not call repository.login', (
    WidgetTester tester,
  ) async {
    final repo = _MockRepo();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repo.login(
        shiftLineId: any<int>(named: 'shiftLineId'),
        pin: any<String>(named: 'pin'),
      ),
    );
  });
}
