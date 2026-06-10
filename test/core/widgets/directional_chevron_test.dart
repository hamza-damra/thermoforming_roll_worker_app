import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/widgets/directional_chevron.dart';

Widget _wrap(TextDirection dir) => MaterialApp(
  home: Directionality(
    textDirection: dir,
    child: const Scaffold(body: Center(child: DirectionalChevron())),
  ),
);

void main() {
  testWidgets('points LEFT in RTL (reading-forward for Arabic)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(TextDirection.rtl));

    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.chevron_left_rounded);
    // The glyph itself is pinned LTR so the framework does not re-mirror it.
    expect(icon.textDirection, TextDirection.ltr);
  });

  testWidgets('points RIGHT in LTR', (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(TextDirection.ltr));

    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.chevron_right_rounded);
  });
}
