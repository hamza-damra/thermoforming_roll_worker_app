import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/domain/entities/roll_label.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/presentation/widgets/label_sticker_widget.dart';

RollLabel _label({
  RollConsumptionState state = RollConsumptionState.partiallyReturned,
}) => RollLabel(
  generatedRollId: '777000000001',
  prefixSnapshot: '777',
  serialNumber: 1,
  rollTypeId: 70,
  rollTypeRollCode: 'TT-1S B250 White',
  rollTypeDisplayName: 'TT-1S B250',
  colorName: 'White',
  standardLengthM: 100.0,
  standardWeightKg: 250.0,
  actualLengthM: 99.5,
  actualWeightKg: 248.0,
  actualThicknessMm: 0.250,
  productionKind: 'NORMAL',
  consumptionState: state,
  lastKnownWeightKg: 75.5,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, c) => Directionality(
      textDirection: TextDirection.rtl,
      child: c ?? const SizedBox.shrink(),
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('renders prescribed Arabic labels and roll details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(LabelStickerWidget(label: _label())));
    await tester.pump();

    expect(find.text('معاينة الليبل'), findsOneWidget);
    expect(find.text('رقم الرول'), findsOneWidget);
    expect(find.text('نوع الرول'), findsOneWidget);
    expect(find.text('الوزن'), findsOneWidget);
    // generatedRollId is rendered both as the centred number and in the
    // info row, so it appears more than once.
    expect(find.text('777000000001'), findsWidgets);
    expect(find.text('TT-1S B250'), findsOneWidget);
    expect(find.text('White'), findsOneWidget);
    // Last-known weight shown prominently with 3-decimal formatting.
    expect(find.text('75.500 كغ'), findsOneWidget);
  });

  testWidgets('renders the partial-return badge for PARTIALLY_RETURNED', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(LabelStickerWidget(label: _label())));
    await tester.pump();

    expect(find.text('إعادة طباعة بعد الإرجاع'), findsOneWidget);
  });

  testWidgets('renders the grinding badge for SENT_TO_GRINDING', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LabelStickerWidget(
          label: _label(state: RollConsumptionState.sentToGrinding),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('إعادة طباعة قبل الجرش'), findsOneWidget);
  });
}
