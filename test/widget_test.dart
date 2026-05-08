import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thermoforming_roll_worker/app/app.dart';
import 'package:thermoforming_roll_worker/core/config/app_config.dart';
import 'package:thermoforming_roll_worker/core/config/config_providers.dart';

void main() {
  testWidgets(
    'Smoke screen renders Arabic title and is RTL when config is complete',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(
              const AppConfig(
                apiBaseUrl: 'https://test.local',
                deviceKey: 'test-device-key',
              ),
            ),
          ],
          child: const RollWorkerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تطبيق عامل الرولات'), findsWidgets);

      final BuildContext context = tester.element(find.byType(Scaffold).first);
      expect(Directionality.of(context), TextDirection.rtl);
    },
  );

  testWidgets(
    'Missing-config gate shows the prescribed Arabic message when config is empty',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWithValue(
              const AppConfig(apiBaseUrl: '', deviceKey: ''),
            ),
          ],
          child: const RollWorkerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppConfig.missingConfigMessage), findsOneWidget);
    },
  );
}
