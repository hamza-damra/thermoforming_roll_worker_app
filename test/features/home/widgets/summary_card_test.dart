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
  group('completed-rolls tile (session-scoped)', () {
    testWidgets(
      'headlines the session-scoped closed-rolls count without a helper note',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const SummaryCard(completedRollsInSession: 7)),
        );

        expect(
          find.text('الرولات التي تم إغلاقها في هذه الجلسة'),
          findsOneWidget,
        );
        expect(find.text('7'), findsOneWidget);
        // V127: the action-breakdown helper note is removed for readability.
        expect(
          find.text('تشمل الاستهلاك الكامل، إرجاع المتبقي، والتوصية بالجرش'),
          findsNothing,
        );
      },
    );

    testWidgets('keeps the "هذه الجلسة" wording (login-session scoped)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SummaryCard(completedRollsInSession: 2)),
      );
      // The completed-rolls metric keeps the "هذه الجلسة" wording.
      expect(find.textContaining('في هذه الجلسة'), findsOneWidget);
    });
  });

  group('V123 consumed-kg tile (operator-shift-line scoped)', () {
    testWidgets('renders the kg value + label, no contributed subline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SummaryCard(
            completedRollsInSession: 8,
            consumedWeightKg: 142.5,
          ),
        ),
      );

      expect(
        find.text('الوزن المُستهلَك في هذه المناوبة (كغم)'),
        findsOneWidget,
      );
      // 3-decimal formatting, matching the consumed-rolls pills.
      expect(find.text('142.500 كغ'), findsOneWidget);
      // V127: the "رولات ساهمت بها" subline is removed.
      expect(find.textContaining('ساهمت'), findsNothing);
      // Completed-rolls tile still present below.
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('a genuine 0.0 shows "0.000 كغ" (not hidden)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SummaryCard(
            completedRollsInSession: 0,
            consumedWeightKg: 0.0,
          ),
        ),
      );

      expect(find.text('0.000 كغ'), findsOneWidget);
      expect(
        find.text('الوزن المُستهلَك في هذه المناوبة (كغم)'),
        findsOneWidget,
      );
    });

    testWidgets('null kg (backend did not compute) hides the kg tile', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SummaryCard(completedRollsInSession: 5)),
      );

      // No fabricated kg figure.
      expect(find.textContaining('كغ'), findsNothing);
      expect(find.textContaining('المناوبة'), findsNothing);
      // Completed-rolls tile still shows.
      expect(find.text('5'), findsOneWidget);
    });
  });

  group('V127 readability cleanup', () {
    testWidgets('renders no decorative icons in the summary cards', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SummaryCard(
            completedRollsInSession: 4,
            consumedWeightKg: 30.0,
          ),
        ),
      );

      // Both stat tiles dropped their leading icon circles (no Icon widgets,
      // and not refreshing so no spinner either).
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('provisional hint', () {
    testWidgets('shows the hint when a roll is mounted', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SummaryCard(
            completedRollsInSession: 1,
            consumedWeightKg: 20.0,
            mountedRollPresent: true,
          ),
        ),
      );

      expect(
        find.text(
          'يشمل الرول المُركّب حالياً ضمن هذه المناوبة كتقدير حتى الإغلاق.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides the hint when no roll is mounted', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SummaryCard(
            completedRollsInSession: 1,
            consumedWeightKg: 20.0,
            // mountedRollPresent: false (default)
          ),
        ),
      );

      expect(find.textContaining('تقدير حتى الإغلاق'), findsNothing);
    });
  });

  testWidgets('shows an inline spinner while refreshing (kg tile present)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SummaryCard(
          completedRollsInSession: 3,
          consumedWeightKg: 5.0,
          isRefreshing: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5.000 كغ'), findsOneWidget);
  });

  testWidgets('shows an inline spinner while refreshing (kg tile hidden)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SummaryCard(completedRollsInSession: 3, isRefreshing: true),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
