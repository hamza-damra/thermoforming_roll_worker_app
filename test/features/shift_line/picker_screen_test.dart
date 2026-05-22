import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_bootstrap_providers.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/roll_worker_lines_sse_providers.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_lines_event.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/roll_worker_bootstrap_repository.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/selected_shift_line_provider.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/screens/active_shift_line_picker_screen.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/widgets/line_waiting_status.dart';

import 'fake_roll_worker_lines_sse_client.dart';

class _MockRepo extends Mock implements RollWorkerBootstrapRepository {}

RollWorkerBootstrapLine _line({
  int thermoformingLineId = 10,
  int? shiftLineId = 500,
  String code = 'TH-01',
  String name = 'Thermo 1',
  bool selectable = true,
  String lifecycle = 'ACTIVE',
  bool handoverPending = false,
  String? takeoverRequestStatus,
  String? blockedReason,
  bool blocked = false,
  String? productName = 'Cup-200ml',
  String? operatorName = 'محمد',
}) => RollWorkerBootstrapLine(
  thermoformingLineId: thermoformingLineId,
  lineCode: code,
  lineName: name,
  machineNumber: 1,
  palletizingLineId: 20,
  productionLineId: 20,
  palletizingLineCode: 'PL-01',
  palletizingLineName: 'Palletizer 1',
  shiftLineId: shiftLineId,
  thermoformingShiftId: 100,
  currentProductTypeId: 50,
  currentProductTypeName: productName,
  activeOperatorId: 7,
  activeOperatorName: operatorName,
  currentRollId: null,
  currentRollGeneratedRollId: null,
  currentRollTypeCode: null,
  currentRollTypeName: null,
  currentRollLastKnownWeightKg: null,
  selectable: selectable,
  canStartRollWorkerSession: selectable,
  blocked: blocked,
  blockedReason: blockedReason,
  handoverPending: handoverPending,
  takeoverRequestStatus: takeoverRequestStatus,
  takeoverIncomingOperatorName: null,
  lineLifecycleStatus: lifecycle,
  updatedAt: null,
);

RollWorkerBootstrapLine _mountedLine() => const RollWorkerBootstrapLine(
  thermoformingLineId: 11,
  lineCode: 'TH-02',
  lineName: 'Thermo 2',
  machineNumber: 2,
  palletizingLineId: 21,
  productionLineId: 21,
  palletizingLineCode: 'PL-02',
  palletizingLineName: 'Palletizer 2',
  shiftLineId: 501,
  thermoformingShiftId: 100,
  currentProductTypeId: 50,
  currentProductTypeName: 'Cup-200ml',
  activeOperatorId: 7,
  activeOperatorName: 'محمد',
  currentRollId: 900,
  currentRollGeneratedRollId: '001000000123',
  currentRollTypeCode: 'RT-A',
  currentRollTypeName: 'Regular Black',
  currentRollLastKnownWeightKg: 180.5,
  selectable: true,
  canStartRollWorkerSession: true,
  blocked: false,
  blockedReason: null,
  handoverPending: false,
  takeoverRequestStatus: null,
  takeoverIncomingOperatorName: null,
  lineLifecycleStatus: 'ACTIVE',
  updatedAt: null,
);

/// Controlled [ProviderScope] — it owns and disposes its container when the
/// widget tree is torn down at the end of the test, cancelling the picker
/// controller's safety-net poll / debounce timers and SSE subscription
/// before flutter_test's pending-timer check.
Widget _wrapped(RollWorkerBootstrapRepository repo, {FakeRollWorkerLinesSseClient? sse}) {
  final FakeRollWorkerLinesSseClient client =
      sse ?? FakeRollWorkerLinesSseClient();
  addTearDown(client.dispose);
  return ProviderScope(
    overrides: <Override>[
      rollWorkerBootstrapRepositoryProvider.overrideWithValue(repo),
      rollWorkerLinesSseClientProvider.overrideWithValue(client),
    ],
    child: const MaterialApp(
      locale: Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ActiveShiftLinePickerScreen(),
      ),
    ),
  );
}

ProviderContainer _containerOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ActiveShiftLinePickerScreen)),
);

void main() {
  testWidgets('empty result → renders the prescribed Arabic waiting copy', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => const RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[]),
    );

    await tester.pumpWidget(_wrapped(repo));
    await tester.pumpAndSettle();

    expect(find.text('بانتظار فتح خط من تطبيق المشغّل'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('rows render line, palletizing, product, operator', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
        _line(),
      ]),
    );

    await tester.pumpWidget(_wrapped(repo));
    await tester.pumpAndSettle();

    expect(find.text('Thermo 1 (TH-01)'), findsOneWidget);
    expect(find.text('Palletizer 1 (PL-01)'), findsOneWidget);
    expect(find.text('Cup-200ml'), findsOneWidget);
    expect(find.text('محمد'), findsOneWidget);
    // Roll section is omitted when no roll is mounted.
    expect(find.text('الرول الحالي'), findsNothing);
  });

  testWidgets('mounted-roll fields render and weight is shown with kg suffix', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
        _mountedLine(),
      ]),
    );

    await tester.pumpWidget(_wrapped(repo));
    await tester.pumpAndSettle();

    expect(find.text('الرول الحالي'), findsOneWidget);
    expect(find.text('001000000123'), findsOneWidget);
    expect(find.text('Regular Black'), findsOneWidget);
    expect(find.text('180.5 kg'), findsOneWidget);
  });

  testWidgets('CTA disabled when no rows ticked, dynamic copy on count', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
        _line(thermoformingLineId: 10, shiftLineId: 500, code: 'TH-01'),
        _line(
          thermoformingLineId: 11,
          shiftLineId: 501,
          code: 'TH-02',
          name: 'Thermo 2',
        ),
      ]),
    );

    await tester.pumpWidget(_wrapped(repo));
    await tester.pumpAndSettle();

    // 0 selected → disabled, prompt copy.
    expect(find.text('اختر على الأقل خطاً واحداً'), findsOneWidget);

    // Tick the first row's checkbox — selection holds shiftLineId, not the
    // row key.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(_containerOf(tester).read(pickerShiftLineSelectionProvider), <int>{
      500,
    });
    expect(find.text('متابعة'), findsOneWidget);

    // Tick the second row.
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(_containerOf(tester).read(pickerShiftLineSelectionProvider), <int>{
      500,
      501,
    });
    expect(find.text('متابعة بـ 2 خطوط'), findsOneWidget);
  });

  testWidgets(
    'selectable row toggles when its card body (not just the checkbox) is '
    'tapped',
    (tester) async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
          _line(),
        ]),
      );

      await tester.pumpWidget(_wrapped(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thermo 1 (TH-01)'));
      await tester.pump();

      expect(_containerOf(tester).read(pickerShiftLineSelectionProvider), <int>{
        500,
      });
    },
  );

  testWidgets(
    'a non-selectable machine row stays visible with a clean status pill and '
    'no disabled checkbox',
    (tester) async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
          _line(
            thermoformingLineId: 12,
            shiftLineId: null,
            code: 'TH-03',
            name: 'Thermo 3',
            selectable: false,
            lifecycle: 'NO_ACTIVE_SHIFT',
          ),
        ]),
      );

      await tester.pumpWidget(_wrapped(repo));
      await tester.pumpAndSettle();

      // The machine row is still rendered…
      expect(find.text('Thermo 3 (TH-03)'), findsOneWidget);
      // …with a calm status pill, not the old orange warning strip…
      expect(find.text(LineWaitingStatus.pillNoActiveShift), findsOneWidget);
      // …and no checkbox at all (hidden, not rendered disabled).
      expect(find.byType(Checkbox), findsNothing);
      // The card is not wrapped in an Opacity dimmer.
      expect(find.byType(Opacity), findsNothing);
    },
  );

  testWidgets(
    'tapping a non-selectable row opens the blocking dialog (NO_ACTIVE_SHIFT '
    'copy) and does not toggle selection',
    (tester) async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
          _line(
            thermoformingLineId: 12,
            shiftLineId: null,
            code: 'TH-03',
            name: 'Thermo 3',
            selectable: false,
            lifecycle: 'NO_ACTIVE_SHIFT',
          ),
        ]),
      );

      await tester.pumpWidget(_wrapped(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Thermo 3 (TH-03)'));
      await tester.pumpAndSettle();

      expect(find.text(LineWaitingStatus.dialogTitle), findsOneWidget);
      expect(
        find.text(LineWaitingStatus.dialogBodyNoActiveShift),
        findsOneWidget,
      );
      expect(find.text(LineWaitingStatus.dialogPrimaryAction), findsOneWidget);
      expect(find.text(LineWaitingStatus.dialogRefreshAction), findsOneWidget);
      // Nothing was selected by the tap.
      expect(
        _containerOf(tester).read(pickerShiftLineSelectionProvider),
        isEmpty,
      );
    },
  );

  testWidgets('PENDING_HANDOVER row → blocking dialog shows the handover copy', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
        _line(
          thermoformingLineId: 13,
          shiftLineId: 600,
          code: 'TH-04',
          name: 'Thermo 4',
          selectable: false,
          lifecycle: 'PENDING_HANDOVER',
          handoverPending: true,
          blockedReason: 'PENDING_HANDOVER',
          blocked: true,
        ),
      ]),
    );

    await tester.pumpWidget(_wrapped(repo));
    await tester.pumpAndSettle();

    expect(find.text(LineWaitingStatus.pillPendingHandover), findsOneWidget);

    await tester.tap(find.text('Thermo 4 (TH-04)'));
    await tester.pumpAndSettle();

    expect(find.text(LineWaitingStatus.dialogTitle), findsOneWidget);
    expect(find.text(LineWaitingStatus.dialogBodyHandover), findsOneWidget);
  });

  testWidgets('TAKEOVER row → blocking dialog shows the takeover copy', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
        _line(
          thermoformingLineId: 14,
          shiftLineId: 601,
          code: 'TH-05',
          name: 'Thermo 5',
          selectable: false,
          lifecycle: 'TAKEOVER_PENDING',
          takeoverRequestStatus: 'PENDING',
          blockedReason: 'TAKEOVER_PENDING',
          blocked: true,
        ),
      ]),
    );

    await tester.pumpWidget(_wrapped(repo));
    await tester.pumpAndSettle();

    expect(find.text(LineWaitingStatus.pillTakeover), findsOneWidget);

    await tester.tap(find.text('Thermo 5 (TH-05)'));
    await tester.pumpAndSettle();

    expect(find.text(LineWaitingStatus.dialogTitle), findsOneWidget);
    expect(find.text(LineWaitingStatus.dialogBodyTakeover), findsOneWidget);
  });

  testWidgets(
    'continue button stays disabled when every row is non-selectable',
    (tester) async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
          _line(
            thermoformingLineId: 12,
            shiftLineId: null,
            code: 'TH-03',
            name: 'Thermo 3',
            selectable: false,
            lifecycle: 'NO_ACTIVE_SHIFT',
          ),
          _line(
            thermoformingLineId: 13,
            shiftLineId: null,
            code: 'TH-04',
            name: 'Thermo 4',
            selectable: false,
            lifecycle: 'NO_ACTIVE_SHIFT',
          ),
        ]),
      );

      await tester.pumpWidget(_wrapped(repo));
      await tester.pumpAndSettle();

      // Both rows visible, no checkboxes, CTA still in its disabled prompt.
      expect(find.text('Thermo 3 (TH-03)'), findsOneWidget);
      expect(find.text('Thermo 4 (TH-04)'), findsOneWidget);
      expect(find.text('اختر على الأقل خطاً واحداً'), findsOneWidget);

      final ElevatedButton cta = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byType(ActiveShiftLinePickerScreen),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(cta.onPressed, isNull);

      // Tapping a non-selectable row opens the dialog, never selects.
      await tester.tap(find.text('Thermo 3 (TH-03)'));
      await tester.pumpAndSettle();
      expect(find.text(LineWaitingStatus.dialogTitle), findsOneWidget);
      expect(
        _containerOf(tester).read(pickerShiftLineSelectionProvider),
        isEmpty,
      );
    },
  );

  testWidgets(
    'background /bootstrap refresh updates a row in place with no full-screen '
    'spinner',
    (tester) async {
      final repo = _MockRepo();
      int call = 0;
      when(repo.fetch).thenAnswer((_) async {
        call++;
        return RollWorkerBootstrapSuccess(<RollWorkerBootstrapLine>[
          _line(productName: call == 1 ? 'Cup-200ml' : 'Cup-500ml'),
        ]);
      });

      final sse = FakeRollWorkerLinesSseClient();
      await tester.pumpWidget(_wrapped(repo, sse: sse));
      await tester.pumpAndSettle();
      expect(find.text('Cup-200ml'), findsOneWidget);

      // A connected SSE handshake triggers an immediate *background* refetch.
      sse.emit(const PickerSseConnected());
      await tester.pump();
      // No full-screen loader flashes during the background refresh.
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();
      // Row updated in place from the authoritative /bootstrap response.
      expect(find.text('Cup-500ml'), findsOneWidget);
      expect(find.text('Cup-200ml'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('failure renders Arabic mapped message with retry affordance', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => const RollWorkerBootstrapFailure(NetworkFailure()),
    );

    await tester.pumpWidget(_wrapped(repo));
    await tester.pumpAndSettle();

    expect(
      find.text('لا يوجد اتصال بالخادم، سيتم إعادة المحاولة تلقائيًا'),
      findsOneWidget,
    );
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}
