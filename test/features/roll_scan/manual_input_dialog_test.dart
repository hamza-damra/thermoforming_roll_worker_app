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

void main() {
  testWidgets('manual input dialog renders Arabic title and buttons', (
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
  });

  testWidgets(
    'rejects non-12-digit input with the format-error inline message',
    (WidgetTester tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(showManualRollInputDialog(navKey.currentContext!));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '12345');
      await tester.tap(find.text('تركيب الرول'));
      await tester.pumpAndSettle();

      // Dialog stays open; inline error is shown.
      expect(find.text('الرجاء إدخال 12 رقمًا بالضبط'), findsOneWidget);
    },
  );

  testWidgets('valid 12-digit input pops with the entered value', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));

    final Future<String?> future = showManualRollInputDialog(
      navKey.currentContext!,
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '777000000001');
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
