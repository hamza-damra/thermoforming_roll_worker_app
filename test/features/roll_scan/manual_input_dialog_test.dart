import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/widgets/manual_roll_input_dialog.dart';

Widget _harness(GlobalKey<NavigatorState> navKey) {
  return MaterialApp(
    theme: AppTheme.light(),
    navigatorKey: navKey,
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const Scaffold(body: SizedBox()),
  );
}

/// The submit (`تركيب الرول`) button — an ElevatedButton under AppPrimaryButton.
ElevatedButton _submitButton(WidgetTester tester) => tester.widget<ElevatedButton>(
  find.widgetWithText(ElevatedButton, 'تركيب الرول'),
);

void main() {
  testWidgets('renders title, helper, example hint (NOT dots) and buttons', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));

    unawaited(showManualRollInputDialog(navKey.currentContext!));
    await tester.pumpAndSettle();

    expect(find.text('إدخال رقم الرول'), findsOneWidget);
    expect(find.text('تركيب الرول'), findsOneWidget);
    expect(find.text('إلغاء'), findsOneWidget);
    expect(find.text('يجب أن يتكون رقم الرول من 12 رقمًا'), findsOneWidget);

    // Placeholder is a clear example, never the old row of dots.
    expect(find.text('مثال: 018000000004'), findsOneWidget);
    expect(find.text('٠٠٠٠٠٠٠٠٠٠٠٠'), findsNothing);

    // Clean counter starts at 0/12.
    expect(find.text('0/12'), findsOneWidget);
  });

  testWidgets('numeric value renders LTR (RTL dialog, LTR digits)', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));
    unawaited(showManualRollInputDialog(navKey.currentContext!));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.textDirection, TextDirection.ltr);
    expect(field.textAlign, TextAlign.center);
    expect(field.maxLength, 12);
  });

  testWidgets('accepts digits only — letters/symbols are filtered out', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));
    unawaited(showManualRollInputDialog(navKey.currentContext!));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '12ab34cd');
    await tester.pumpAndSettle();

    expect(find.text('1234'), findsOneWidget);
    expect(find.text('4/12'), findsOneWidget);
  });

  testWidgets('limits input to 12 digits', (WidgetTester tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));
    unawaited(showManualRollInputDialog(navKey.currentContext!));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0180000000049999');
    await tester.pumpAndSettle();

    expect(find.text('018000000004'), findsOneWidget);
    expect(find.text('12/12'), findsOneWidget);
  });

  testWidgets('submit is DISABLED below 12 digits and does not pop', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));
    final Future<String?> future = showManualRollInputDialog(
      navKey.currentContext!,
    );
    await tester.pumpAndSettle();

    // Empty → disabled.
    expect(_submitButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pumpAndSettle();

    expect(find.text('5/12'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNull);

    // Tapping the disabled button is a no-op — dialog stays open.
    await tester.tap(find.text('تركيب الرول'));
    await tester.pumpAndSettle();
    expect(find.text('إدخال رقم الرول'), findsOneWidget);

    // Clean up so the pending dialog future doesn't dangle.
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('submit is ENABLED at exactly 12 digits and pops the value', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));
    final Future<String?> future = showManualRollInputDialog(
      navKey.currentContext!,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '777000000001');
    await tester.pumpAndSettle();

    expect(find.text('12/12'), findsOneWidget);
    expect(_submitButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('تركيب الرول'));
    await tester.pumpAndSettle();

    expect(await future, '777000000001');
  });

  testWidgets('cancel pops with null', (WidgetTester tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));

    final Future<String?> future = showManualRollInputDialog(
      navKey.currentContext!,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(await future, isNull);
  });
}

// Defined locally to avoid importing dart:async just for unawaited.
void unawaited(Future<dynamic>? future) {}
