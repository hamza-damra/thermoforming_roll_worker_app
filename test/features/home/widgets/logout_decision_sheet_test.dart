import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/logout_decision_sheet.dart';

Widget _harness(GlobalKey<NavigatorState> navKey) => MaterialApp(
  theme: AppTheme.light(),
  navigatorKey: navKey,
  builder: (context, child) => Directionality(
    textDirection: TextDirection.rtl,
    child: child ?? const SizedBox.shrink(),
  ),
  home: const Scaffold(body: SizedBox()),
);

void main() {
  testWidgets('shows the four options in the EXACT prescribed order', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));
    showLogoutDecisionSheet(navKey.currentContext!);
    await tester.pumpAndSettle();

    const List<String> expected = <String>[
      'الرول ما زال مركب للموظف التالي',
      'استهلاك كامل وإنزال الرول',
      'إرجاع المتبقي',
      'إرسال للجرش',
    ];
    for (final String label in expected) {
      expect(find.text(label), findsOneWidget);
    }

    // Vertical order matches the prescribed order.
    double dy(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(dy(expected[0]), lessThan(dy(expected[1])));
    expect(dy(expected[1]), lessThan(dy(expected[2])));
    expect(dy(expected[2]), lessThan(dy(expected[3])));
  });

  testWidgets('tapping option 1 returns LogoutDecision.keepMounted', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));
    final Future<LogoutDecision?> future = showLogoutDecisionSheet(
      navKey.currentContext!,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الرول ما زال مركب للموظف التالي'));
    await tester.pumpAndSettle();

    expect(await future, LogoutDecision.keepMounted);
  });

  testWidgets('tapping إرسال للجرش returns LogoutDecision.grinding', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));
    final Future<LogoutDecision?> future = showLogoutDecisionSheet(
      navKey.currentContext!,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('إرسال للجرش'));
    await tester.pumpAndSettle();

    expect(await future, LogoutDecision.grinding);
  });
}
