import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/core/widgets/primary_bottom_action.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, c) => Directionality(
    textDirection: TextDirection.rtl,
    child: c ?? const SizedBox.shrink(),
  ),
  home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
);

void main() {
  testWidgets('without a secondary label only the primary button renders', (
    tester,
  ) async {
    int primary = 0;
    await tester.pumpWidget(
      _wrap(
        PrimaryBottomAction(label: 'تركيب رول', onPressed: () => primary++),
      ),
    );
    expect(find.text('تركيب رول'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);

    await tester.tap(find.text('تركيب رول'));
    expect(primary, 1);
  });

  testWidgets('a secondary action renders above the primary and has its own '
      'callback', (tester) async {
    int primary = 0;
    int secondary = 0;
    await tester.pumpWidget(
      _wrap(
        PrimaryBottomAction(
          label: 'تركيب رول',
          onPressed: () => primary++,
          secondaryLabel: 'بحث بوقت الإنتاج',
          secondaryIcon: Icons.manage_search_rounded,
          onSecondaryPressed: () => secondary++,
        ),
      ),
    );
    expect(find.text('بحث بوقت الإنتاج'), findsOneWidget);
    expect(find.byIcon(Icons.manage_search_rounded), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('بحث بوقت الإنتاج')).dy,
      lessThan(tester.getTopLeft(find.text('تركيب رول')).dy),
    );

    await tester.tap(find.text('بحث بوقت الإنتاج'));
    expect(secondary, 1);
    expect(primary, 0);

    await tester.tap(find.text('تركيب رول'));
    expect(primary, 1);
    expect(secondary, 1);
  });
}
