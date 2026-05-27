import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/entities/roll_scan_warning.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/widgets/curing_max_warning_dialog.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/widgets/curing_min_violation_dialog.dart';

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
  group('showCuringMinViolationDialog', () {
    testWidgets('renders blocking title + serverMessage body', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showCuringMinViolationDialog(
          navKey.currentContext!,
          failure: const BusinessFailure(
            code: ErrorCode.rollCuringMinimumNotMet,
            statusCode: 409,
            serverMessage:
                'لا يمكن تركيب هذا الرول الآن. مدة الحضانة المطلوبة 5 يوم.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا يمكن تركيب الرول'), findsOneWidget);
      expect(
        find.text(
          'لا يمكن تركيب هذا الرول الآن. مدة الحضانة المطلوبة 5 يوم.',
        ),
        findsOneWidget,
      );
      expect(find.text('حسناً'), findsOneWidget);
    });

    testWidgets('falls back to static Arabic when serverMessage is null', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showCuringMinViolationDialog(
          navKey.currentContext!,
          failure: const BusinessFailure(
            code: ErrorCode.rollCuringMinimumNotMet,
            statusCode: 409,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Handoff §7.1 wording (replaces the in-house phrasing).
      expect(
        find.text('هذا الرول لم يكتمل فترة الحضانة الدنيا بعد.'),
        findsOneWidget,
      );
    });

    testWidgets('dismiss button pops the dialog', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      bool resolved = false;
      unawaited(
        showCuringMinViolationDialog(
          navKey.currentContext!,
          failure: const BusinessFailure(
            code: ErrorCode.rollCuringMinimumNotMet,
            serverMessage: 'msg',
          ),
        ).then((_) => resolved = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(find.text('لا يمكن تركيب الرول'), findsNothing);
    });
  });

  group('showCuringMaxWarningDialog', () {
    testWidgets('renders title, server-authored message, and admin note', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showCuringMaxWarningDialog(
          navKey.currentContext!,
          warning: const RollScanWarning(
            code: 'ROLL_CURING_MAXIMUM_EXCEEDED',
            severity: 'WARNING',
            message:
                'تنبيه: عمر هذا الرول تجاوز الحد الأعلى للحضانة. يمكنك المتابعة.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تنبيه — تجاوز الحضانة الأعلى'), findsOneWidget);
      expect(
        find.text(
          'تنبيه: عمر هذا الرول تجاوز الحد الأعلى للحضانة. يمكنك المتابعة.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('تم إشعار الإدارة. يمكنك المتابعة في العمل.'),
        findsOneWidget,
      );
      expect(find.text('متابعة'), findsOneWidget);
    });

    testWidgets('continue button pops the dialog', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      bool resolved = false;
      unawaited(
        showCuringMaxWarningDialog(
          navKey.currentContext!,
          warning: const RollScanWarning(
            code: 'ROLL_CURING_MAXIMUM_EXCEEDED',
            severity: 'WARNING',
            message: 'm',
          ),
        ).then((_) => resolved = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(find.text('تنبيه — تجاوز الحضانة الأعلى'), findsNothing);
    });
  });
}
