import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/domain/entities/roll_label.dart';
import 'package:thermoforming_roll_worker/features/label_reprint/presentation/widgets/reprint_badge.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, c) => Directionality(
      textDirection: TextDirection.rtl,
      child: c ?? const SizedBox.shrink(),
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('PARTIALLY_RETURNED → renders "إعادة طباعة بعد الإرجاع"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ReprintBadge(
          consumptionState: RollConsumptionState.partiallyReturned,
        ),
      ),
    );
    expect(find.text('إعادة طباعة بعد الإرجاع'), findsOneWidget);
    expect(find.text('إعادة طباعة قبل الجرش'), findsNothing);
  });

  testWidgets('SENT_TO_GRINDING → renders "إعادة طباعة قبل الجرش"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ReprintBadge(
          consumptionState: RollConsumptionState.sentToGrinding,
        ),
      ),
    );
    expect(find.text('إعادة طباعة قبل الجرش'), findsOneWidget);
  });

  testWidgets('Other states fall back to the generic prescribed copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ReprintBadge(consumptionState: RollConsumptionState.consumed),
      ),
    );
    expect(find.text('إعادة طباعة الليبل'), findsOneWidget);
  });
}
