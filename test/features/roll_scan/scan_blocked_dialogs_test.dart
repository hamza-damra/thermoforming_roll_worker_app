import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/widgets/roll_scan_blocked_dialog.dart';

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

BusinessFailure _failure(
  ErrorCode code,
  Map<String, Object?>? details,
) => BusinessFailure(code: code, statusCode: 409, details: details);

void main() {
  group('grinding-recommended dialog', () {
    testWidgets('renders title, details, reason note, and guidance', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showRollScanBlockedDialog(
          navKey.currentContext!,
          kind: RollScanBlockedKind.grinding,
          failure: _failure(ErrorCode.rollSentToGrindingNotReusable, {
            'rollNumber': '001000000123',
            'workerName': 'محمد',
            'workerReasonText': 'الرول فيه مشكلة واضحة',
            'remainingWeightKg': 12.5,
            // UTC "Z", matching the backend wire format. 07:30Z renders as
            // 10:30 factory time (Asia/Hebron, +03:00 in summer) on any
            // device, whatever the test machine's timezone.
            'recommendedAt': '2026-06-23T07:30:00Z',
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الرول موصى بالجرش'), findsOneWidget);
      expect(
        find.text('هذا الرول موصى بالجرش ولا يمكن تركيبه كمتبقي صالح.'),
        findsOneWidget,
      );
      // Detail rows (value cells).
      expect(find.text('001000000123'), findsOneWidget);
      expect(find.text('محمد'), findsOneWidget);
      expect(find.text('12.500 كغ'), findsOneWidget);
      expect(find.text('23-06-2026، 10:30 صباحًا'), findsOneWidget);
      // The recommender's note is rendered as its own card.
      expect(find.text('الرول فيه مشكلة واضحة'), findsOneWidget);
      expect(find.textContaining('سبب التوصية'), findsWidgets);
      // Guidance line + OK button.
      expect(find.textContaining('تواصل مع م. حمزه ضمره'), findsOneWidget);
      expect(find.text('حسنًا'), findsOneWidget);

      // RTL.
      expect(
        Directionality.of(tester.element(find.text('الرول موصى بالجرش'))),
        TextDirection.rtl,
      );
    });

    testWidgets('prefers a backend-authored details.message', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showRollScanBlockedDialog(
          navKey.currentContext!,
          kind: RollScanBlockedKind.grinding,
          failure: _failure(ErrorCode.rollSentToGrindingNotReusable, {
            'rollNumber': '001000000123',
            'message': 'رسالة من الخادم.',
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('رسالة من الخادم.'), findsOneWidget);
    });
  });

  group('consumed dialog', () {
    testWidgets('renders consumed title, message, and guidance', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showRollScanBlockedDialog(
          navKey.currentContext!,
          kind: RollScanBlockedKind.consumed,
          failure: _failure(ErrorCode.rollAlreadyConsumed, {
            'rollNumber': '001000000123',
            'workerName': 'محمد',
            // 06:00Z -> 09:00 factory time (Asia/Hebron, +03:00 in summer).
            'consumedAt': '2026-06-23T06:00:00Z',
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الرول مستهلك بالكامل'), findsOneWidget);
      expect(find.text('هذا الرول مستهلك بالكامل.'), findsOneWidget);
      expect(find.text('001000000123'), findsOneWidget);
      expect(find.text('محمد'), findsOneWidget);
      expect(find.text('23-06-2026، 09:00 صباحًا'), findsOneWidget);
      expect(
        find.textContaining('تواصل مع الإدارة'),
        findsOneWidget,
      );
    });
  });

  group('admin-cancelled dialog', () {
    testWidgets('renders cancellation metadata', (WidgetTester tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showRollScanBlockedDialog(
          navKey.currentContext!,
          kind: RollScanBlockedKind.adminCancelled,
          failure: _failure(ErrorCode.rollAdminCancelled, {
            'rollNumber': '001000000123',
            'cancelledBy': 'م. حمزه ضمره',
            'cancelReason': 'رول قديم استُهلك فعلياً',
            // 11:00Z -> 14:00 factory time (Asia/Hebron, +03:00 in summer).
            'cancelledAt': '2026-06-20T11:00:00Z',
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الرول ملغى'), findsOneWidget);
      expect(
        find.text('تم إلغاء هذا الرول من الإدارة ولا يمكن تركيبه.'),
        findsOneWidget,
      );
      expect(find.text('م. حمزه ضمره'), findsOneWidget);
      expect(find.text('رول قديم استُهلك فعلياً'), findsOneWidget);
      expect(find.text('20-06-2026، 02:00 مساءً'), findsOneWidget);
    });
  });

  group('reconciled-out-of-stock dialog', () {
    // V132 pins `details: null` on this code, so the dialog's static copy is
    // the only thing the worker reads — assert it renders without any payload.
    testWidgets('null details → title, message, guidance, OK; no rows', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showRollScanBlockedDialog(
          navKey.currentContext!,
          kind: RollScanBlockedKind.reconciledOutOfStock,
          failure: _failure(ErrorCode.rollReconciledOutOfStock, null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الرول مُسوّى مخزونياً'), findsOneWidget);
      expect(
        find.text('تمت تسوية هذا الرول مخزونياً ولا يمكن تركيبه.'),
        findsOneWidget,
      );
      expect(find.textContaining('تواصل مع الإدارة'), findsOneWidget);
      // No detail rows, and never the admin-cancelled copy.
      expect(find.textContaining('رقم الرول'), findsNothing);
      expect(find.textContaining('تم إلغاء هذا الرول'), findsNothing);
      expect(find.text('حسنًا'), findsOneWidget);
    });

    testWidgets('renders the roll number if the backend ever echoes one', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showRollScanBlockedDialog(
          navKey.currentContext!,
          kind: RollScanBlockedKind.reconciledOutOfStock,
          failure: _failure(ErrorCode.rollReconciledOutOfStock, {
            'rollNumber': '001000000123',
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('001000000123'), findsOneWidget);
    });
  });

  group('missing / null details safety', () {
    testWidgets('null details → title + static message + OK, no rows', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showRollScanBlockedDialog(
          navKey.currentContext!,
          kind: RollScanBlockedKind.consumed,
          failure: _failure(ErrorCode.rollAlreadyConsumed, null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الرول مستهلك بالكامل'), findsOneWidget);
      expect(find.text('هذا الرول مستهلك بالكامل.'), findsOneWidget);
      // No detail rows rendered.
      expect(find.textContaining('رقم الرول'), findsNothing);
      expect(find.textContaining('العامل'), findsNothing);
      expect(find.text('حسنًا'), findsOneWidget);
    });

    testWidgets('partial details render only the present rows', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_harness(navKey));

      unawaited(
        showRollScanBlockedDialog(
          navKey.currentContext!,
          kind: RollScanBlockedKind.adminCancelled,
          failure: _failure(ErrorCode.rollAdminCancelled, {
            'rollNumber': '001000000123',
            // cancelledBy / cancelReason / cancelledAt all missing.
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('001000000123'), findsOneWidget);
      expect(find.textContaining('ألغاه'), findsNothing);
      expect(find.textContaining('سبب الإلغاء'), findsNothing);
      expect(find.textContaining('وقت الإلغاء'), findsNothing);
    });
  });

  testWidgets('OK button pops the dialog', (WidgetTester tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_harness(navKey));

    bool resolved = false;
    unawaited(
      showRollScanBlockedDialog(
        navKey.currentContext!,
        kind: RollScanBlockedKind.consumed,
        failure: _failure(ErrorCode.rollAlreadyConsumed, null),
      ).then((_) => resolved = true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('حسنًا'));
    await tester.pumpAndSettle();

    expect(resolved, isTrue);
    expect(find.text('الرول مستهلك بالكامل'), findsNothing);
  });
}
