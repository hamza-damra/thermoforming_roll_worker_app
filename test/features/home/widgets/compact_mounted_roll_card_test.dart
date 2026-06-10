import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/compact_mounted_roll_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, body) => Directionality(
    textDirection: TextDirection.rtl,
    child: Material(child: body ?? const SizedBox.shrink()),
  ),
  home: Padding(padding: const EdgeInsets.all(16), child: child),
);

SummaryMountedRoll _roll({double? lastKnownWeightKg}) => SummaryMountedRoll(
  consumptionItemId: 555,
  rollId: 67890,
  generatedRollId: '001000000777',
  rollTypeCode: 'TP-1',
  rollTypeName: 'White',
  lastKnownWeightKg: lastKnownWeightKg,
);

void main() {
  testWidgets(
    'renders the roll number and the latest-known weight row (3 decimals + كغ)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(CompactMountedRollCard(roll: _roll(lastKnownWeightKg: 101.0))),
      );

      // Heading + roll id unchanged.
      expect(find.text('الرول المركب حالياً'), findsOneWidget);
      expect(find.text('001000000777'), findsOneWidget);

      // New read-only weight row.
      expect(find.text('آخر وزن معروف'), findsOneWidget);
      expect(find.text('101.000 كغ'), findsOneWidget);
      // The "unavailable" message must NOT show when a weight exists.
      expect(find.text('الوزن غير متوفر'), findsNothing);
    },
  );

  testWidgets('formats a fractional weight to exactly 3 decimals', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(CompactMountedRollCard(roll: _roll(lastKnownWeightKg: 0.5))),
    );

    expect(find.text('0.500 كغ'), findsOneWidget);
  });

  testWidgets(
    'null weight shows "الوزن غير متوفر" but still shows the roll id',
    (tester) async {
      await tester.pumpWidget(
        _wrap(CompactMountedRollCard(roll: _roll())),
      );

      // Roll id + label still render.
      expect(find.text('001000000777'), findsOneWidget);
      expect(find.text('آخر وزن معروف'), findsOneWidget);

      // Unavailable copy instead of a number; no كغ value is shown.
      expect(find.text('الوزن غير متوفر'), findsOneWidget);
      expect(find.textContaining('كغ'), findsNothing);
    },
  );
}
