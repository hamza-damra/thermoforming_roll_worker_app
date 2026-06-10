import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/summary_card.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, body) => Directionality(
    textDirection: TextDirection.rtl,
    child: Material(child: body ?? const SizedBox.shrink()),
  ),
  home: Padding(padding: const EdgeInsets.all(16), child: child),
);

void main() {
  testWidgets('renders the session-scoped heading and counter', (tester) async {
    await tester.pumpWidget(
      _wrap(const SummaryCard(
        completedRollsInSession: 7,
        completedRollsByCurrentWorker: 0,
      )),
    );

    expect(find.text('الرولات المنجزة في هذه الجلسة'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets(
    'hides "منك" sub-line when both counters are equal (avoid duplicate)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const SummaryCard(
          completedRollsInSession: 4,
          completedRollsByCurrentWorker: 4,
        )),
      );

      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('منك'), findsNothing);
    },
  );

  testWidgets(
    'shows "منك" sub-line when the two counters disagree (legacy data)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const SummaryCard(
          completedRollsInSession: 8,
          completedRollsByCurrentWorker: 3,
        )),
      );

      expect(find.text('8'), findsOneWidget);
      expect(find.text('منك: 3'), findsOneWidget);
    },
  );

  testWidgets('hides "منك" sub-line when the value is zero', (tester) async {
    await tester.pumpWidget(
      _wrap(const SummaryCard(
        completedRollsInSession: 5,
        completedRollsByCurrentWorker: 0,
      )),
    );

    expect(find.textContaining('منك'), findsNothing);
  });

  testWidgets(
    'V104: leads with consumed-kg headline + rolls-contributed subline',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const SummaryCard(
          completedRollsInSession: 3,
          completedRollsByCurrentWorker: 3,
          consumedWeightKgInSession: 142.5,
          rollsContributedInSession: 3,
        )),
      );

      expect(find.text('المستهلك في هذه الجلسة'), findsOneWidget);
      expect(find.text('142.5 كغ'), findsOneWidget);
      expect(find.text('ساهمت في: 3 رولات'), findsOneWidget);
      // The legacy completed-rolls heading is not shown when kg is present.
      expect(find.text('الرولات المنجزة في هذه الجلسة'), findsNothing);
    },
  );

  testWidgets(
    'V104: falls back to completed-rolls headline when kg is null (legacy)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const SummaryCard(
          completedRollsInSession: 7,
          completedRollsByCurrentWorker: 0,
          rollsContributedInSession: 0,
        )),
      );

      expect(find.text('الرولات المنجزة في هذه الجلسة'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.textContaining('المستهلك'), findsNothing);
    },
  );
}
