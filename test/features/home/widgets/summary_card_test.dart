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
  testWidgets(
    'V109: headlines the session-scoped closed-rolls count + action subtitle',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const SummaryCard(completedRollsInSession: 7)),
      );

      expect(
        find.text('الرولات التي تم إغلاقها في هذه الجلسة'),
        findsOneWidget,
      );
      expect(find.text('7'), findsOneWidget);
      expect(
        find.text('تشمل الاستهلاك الكامل، إرجاع المتبقي، والتوصية بالجرش'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows 0 at session start without any kg metric', (tester) async {
    await tester.pumpWidget(
      _wrap(const SummaryCard(completedRollsInSession: 0)),
    );

    expect(find.text('0'), findsOneWidget);
    // V109: never present a fabricated per-worker kg figure.
    expect(find.textContaining('كغ'), findsNothing);
    expect(find.textContaining('المستهلك'), findsNothing);
    // No personal-productivity attribution.
    expect(find.textContaining('منك'), findsNothing);
    expect(find.textContaining('ساهمت'), findsNothing);
  });

  testWidgets('shows an inline spinner while refreshing', (tester) async {
    await tester.pumpWidget(
      _wrap(const SummaryCard(completedRollsInSession: 3, isRefreshing: true)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
