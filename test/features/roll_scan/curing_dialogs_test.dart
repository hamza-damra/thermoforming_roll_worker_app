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
    testWidgets(
      'renders Arabic copy + hours details, never the raw backend message',
      (WidgetTester tester) async {
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_harness(navKey));

        unawaited(
          showCuringMinViolationDialog(
            navKey.currentContext!,
            failure: const BusinessFailure(
              code: ErrorCode.rollCuringMinimumNotMet,
              statusCode: 409,
              // English backend message MUST be suppressed.
              serverMessage:
                  'Roll 009000000107 has not met the minimum curing '
                  'period (48h). Actual age: 45h',
              details: <String, Object?>{
                'rollId': '009000000107',
                'minCuringHours': 48,
                'actualAgeHours': 45,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('لا يمكن تركيب الرول'), findsOneWidget);
        // Lead sentence names the roll inline and uses the "الدنيا" (minimum)
        // wording so it is distinct from the curing-MAX warning.
        expect(
          find.text('الرول 009000000107 لم يكمل مدة الحضانة الدنيا المطلوبة.'),
          findsOneWidget,
        );
        expect(find.text('العمر الحالي: 45 ساعة.'), findsOneWidget);
        expect(find.text('الحد الأدنى المطلوب: 48 ساعة.'), findsOneWidget);
        expect(
          find.text(
            'يرجى الانتظار حتى اكتمال مدة الحضانة ثم المحاولة مرة أخرى.',
          ),
          findsOneWidget,
        );
        expect(find.text('حسنًا'), findsOneWidget);

        // The English backend message and the forbidden term must be absent.
        expect(find.textContaining('curing period'), findsNothing);
        expect(find.textContaining('has not met'), findsNothing);
        expect(find.textContaining('Actual age'), findsNothing);
        expect(find.textContaining('التخمير'), findsNothing);
      },
    );

    testWidgets('omits detail lines when details are missing (no crash)', (
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

      // No roll id and no details → the safe Arabic fallback sentence renders.
      expect(
        find.text(
          'هذا الرول لم يكمل مدة الحضانة الدنيا المطلوبة ولا يمكن تركيبه الآن.',
        ),
        findsOneWidget,
      );
      // No details → no current-age / minimum-required lines, but the dialog
      // still renders cleanly.
      expect(find.textContaining('العمر الحالي:'), findsNothing);
      expect(find.textContaining('الحد الأدنى المطلوب:'), findsNothing);
      expect(find.text('حسنًا'), findsOneWidget);
    });

    testWidgets('falls back to scanned roll number when details omit it', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showCuringMinViolationDialog(
          navKey.currentContext!,
          failure: const BusinessFailure(
            code: ErrorCode.rollCuringMinimumNotMet,
            details: <String, Object?>{'minCuringHours': 48},
          ),
          rollNumber: '009000000107',
        ),
      );
      await tester.pumpAndSettle();

      // The scanned roll number is woven into the lead sentence.
      expect(
        find.text('الرول 009000000107 لم يكمل مدة الحضانة الدنيا المطلوبة.'),
        findsOneWidget,
      );
      expect(find.text('الحد الأدنى المطلوب: 48 ساعة.'), findsOneWidget);
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
          ),
        ).then((_) => resolved = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('حسنًا'));
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
