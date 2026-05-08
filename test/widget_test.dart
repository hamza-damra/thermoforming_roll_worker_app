import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thermoforming_roll_worker/app/app.dart';

void main() {
  testWidgets('App renders Arabic title and is RTL', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: RollWorkerApp()));
    await tester.pumpAndSettle();

    expect(find.text('تطبيق عامل الرولات'), findsWidgets);

    final BuildContext context = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(context), TextDirection.rtl);
  });
}
