import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/batch_auth_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/entities/roll_worker_session.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/session_batch_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/presentation/screens/pin_screen.dart';

class _MockBatchRepo extends Mock implements SessionBatchRepository {}

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

ShiftLineSummaryRepository _summaryRepo() {
  final repo = _MockSummaryRepo();
  when(
    () => repo.fetchSummary(shiftLineId: any(named: 'shiftLineId')),
  ).thenAnswer((invocation) async {
    final int id =
        invocation.namedArguments[const Symbol('shiftLineId')] as int;
    return SummarySuccess(
      ShiftLineSummary(
        shiftLineId: id,
        thermoformingLineCode: 'TH-01',
        thermoformingLineName: 'خط التشكيل 1',
        completedRollsInShift: 0,
        completedRollsByCurrentWorker: 0,
        activeOperatorName: 'مشغل التشكيل',
      ),
    );
  });
  return repo;
}

const Set<int> kShiftLineIds = <int>{800, 801};

Widget _wrap({required _MockBatchRepo repo}) {
  return ProviderScope(
    overrides: <Override>[
      sessionBatchRepositoryProvider.overrideWithValue(repo),
      shiftLineSummaryRepositoryProvider.overrideWithValue(_summaryRepo()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const PinScreen(shiftLineIds: kShiftLineIds),
    ),
  );
}

BatchAuthOutcome _outcome() => BatchAuthOutcome(
  rollWorkerOperatorId: 77,
  rollWorkerName: 'Yusuf',
  sessions: <int, RollWorkerSession>{
    800: RollWorkerSession(
      sessionId: 1,
      rollWorkerOperatorId: 77,
      rollWorkerName: 'Yusuf',
      thermoformingShiftId: 9001,
      thermoformingShiftLineId: 800,
      thermoformingLineId: 11,
      palletizingLineId: 21,
      startedAt: DateTime.parse('2026-05-10T10:00:00Z'),
    ),
    801: RollWorkerSession(
      sessionId: 2,
      rollWorkerOperatorId: 77,
      rollWorkerName: 'Yusuf',
      thermoformingShiftId: 9001,
      thermoformingShiftLineId: 801,
      thermoformingLineId: 12,
      palletizingLineId: 22,
      startedAt: DateTime.parse('2026-05-10T10:00:00Z'),
    ),
  },
);

void main() {
  testWidgets('renders Arabic title and submit button', (tester) async {
    final repo = _MockBatchRepo();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل دخول عامل الرولات'), findsWidgets);
    expect(find.text('دخول'), findsOneWidget);
  });

  testWidgets('typing PIN and submitting calls startBatch with the Set', (
    tester,
  ) async {
    final repo = _MockBatchRepo();
    when(
      () => repo.startBatch(
        pin: '1234',
        shiftLineIds: kShiftLineIds,
      ),
    ).thenAnswer((_) async => BatchAuthSuccessResult(_outcome()));

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    verify(
      () => repo.startBatch(pin: '1234', shiftLineIds: kShiftLineIds),
    ).called(1);
  });

  testWidgets('OPERATOR_PIN_INVALID surfaces inline Arabic error', (
    tester,
  ) async {
    final repo = _MockBatchRepo();
    when(
      () => repo.startBatch(
        pin: any<String>(named: 'pin'),
        shiftLineIds: any<Set<int>>(named: 'shiftLineIds'),
      ),
    ).thenAnswer(
      (_) async => const BatchAuthFailureResult(
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

  testWidgets('OPERATOR_LOCKED surfaces locked helper and disables submit', (
    tester,
  ) async {
    final repo = _MockBatchRepo();
    when(
      () => repo.startBatch(
        pin: any<String>(named: 'pin'),
        shiftLineIds: any<Set<int>>(named: 'shiftLineIds'),
      ),
    ).thenAnswer(
      (_) async => const BatchAuthFailureResult(
        BusinessFailure(code: ErrorCode.operatorLocked),
      ),
    );

    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text(PinScreen.pinLockedHelper), findsOneWidget);
  });

  testWidgets('ROLL_WORKER_NOT_ALLOWED surfaces unauthorized helper', (
    tester,
  ) async {
    final repo = _MockBatchRepo();
    when(
      () => repo.startBatch(
        pin: any<String>(named: 'pin'),
        shiftLineIds: any<Set<int>>(named: 'shiftLineIds'),
      ),
    ).thenAnswer(
      (_) async => const BatchAuthFailureResult(
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
  });

  testWidgets('empty PIN does not call repository.startBatch', (tester) async {
    final repo = _MockBatchRepo();
    await tester.pumpWidget(_wrap(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    verifyNever(
      () => repo.startBatch(
        pin: any<String>(named: 'pin'),
        shiftLineIds: any<Set<int>>(named: 'shiftLineIds'),
      ),
    );
  });
}
