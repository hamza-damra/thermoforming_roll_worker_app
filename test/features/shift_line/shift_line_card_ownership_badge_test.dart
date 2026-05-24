import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/widgets/shift_line_card.dart';

/// PR D — the "أنت تعمل على هذا الخط" ownership chip on [ShiftLineCard].
/// Parents compute the boolean from
/// `multiLineSessionRegistryProvider.activeShiftLineIds`; the widget only
/// renders it when [ShiftLineCard.ownedByMe] is `true`.
const RollWorkerBootstrapLine _line = RollWorkerBootstrapLine(
  thermoformingLineId: 10,
  lineCode: 'TH-01',
  lineName: 'Thermo 1',
  machineNumber: 1,
  palletizingLineId: 20,
  productionLineId: 20,
  palletizingLineCode: 'PL-01',
  palletizingLineName: 'Palletizer 1',
  shiftLineId: 500,
  thermoformingShiftId: 100,
  currentProductTypeId: 50,
  currentProductTypeName: 'Cup-200ml',
  activeOperatorId: 7,
  activeOperatorName: 'محمد',
  currentRollId: null,
  currentRollGeneratedRollId: null,
  currentRollTypeCode: null,
  currentRollTypeName: null,
  currentRollLastKnownWeightKg: null,
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

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'ownedByMe = false (default) → no ownership chip is rendered',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ShiftLineCard(
            line: _line,
            selected: false,
            conflicted: false,
            onToggle: (_) {},
          ),
        ),
      );

      expect(find.text('أنت تعمل على هذا الخط'), findsNothing);
      // The check-circle icon is also a tell — make sure it isn't drawn.
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    },
  );

  testWidgets(
    'ownedByMe = true → renders the Arabic chip and the check-circle icon',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ShiftLineCard(
            line: _line,
            selected: false,
            conflicted: false,
            onToggle: (_) {},
            ownedByMe: true,
          ),
        ),
      );

      expect(find.text('أنت تعمل على هذا الخط'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'custom ownedByMeLabel overrides the default Arabic copy',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ShiftLineCard(
            line: _line,
            selected: false,
            conflicted: false,
            onToggle: (_) {},
            ownedByMe: true,
            ownedByMeLabel: 'خطك الحالي',
          ),
        ),
      );

      expect(find.text('خطك الحالي'), findsOneWidget);
      expect(find.text('أنت تعمل على هذا الخط'), findsNothing);
    },
  );
}
