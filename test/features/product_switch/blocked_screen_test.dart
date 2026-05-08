import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/product_switch/presentation/screens/product_switch_blocked_screen.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/entities/mounted_roll.dart';

MountedRoll _mounted() => const MountedRoll(
  rollId: 1,
  generatedRollId: '777000000001',
  rollTypeId: 70,
  rollTypeRollCode: 'TT-1S B250 White',
  rollTypeDisplayName: 'TT-1S B250',
  colorName: 'White',
  productTypeId: 5,
  productTypeName: 'أحمر 20 كغ',
  consumptionItemId: 5000,
  activeSegmentId: 6000,
  state: 'IN_CONSUMPTION',
  lastKnownWeightKg: 250.0,
);

Widget _wrap(Widget home) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: home,
  );
}

void main() {
  testWidgets('renders prescribed Arabic title, blocked title, body, helper', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProductSwitchBlockedScreen()));
    await tester.pumpAndSettle();

    expect(find.text('تغيير المنتج'), findsWidgets);
    expect(find.text('تغيير المنتج غير متاح حاليًا'), findsOneWidget);
    expect(
      find.text('بانتظار دعم الخادم لعرض المنتجات المتوافقة مع الرول الحالي.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'لا يمكن تغيير المنتج قبل توفر قائمة المنتجات المتوافقة من الخادم.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('submit button is rendered visibly disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProductSwitchBlockedScreen()));
    await tester.pumpAndSettle();

    final ElevatedButton submit = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('shows current product + roll-type when a mount is provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ProductSwitchBlockedScreen(mountedRoll: _mounted())),
    );
    await tester.pumpAndSettle();

    expect(find.text('المنتج الحالي'), findsOneWidget);
    expect(find.text('أحمر 20 كغ'), findsOneWidget);
    expect(find.text('نوع الرول الحالي'), findsOneWidget);
    expect(find.text('TT-1S B250'), findsOneWidget);
  });

  testWidgets('contains no product picker / dropdown / list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ProductSwitchBlockedScreen(mountedRoll: _mounted())),
    );
    await tester.pumpAndSettle();

    // No product-selector widgets are rendered. The blocked shell has no
    // way to choose an alternative product.
    expect(find.byType(DropdownButton<dynamic>), findsNothing);
    expect(find.byType(ListView), findsOneWidget); // outer scroll only
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(RadioListTile<dynamic>), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    // Only the disabled submit; no other text-input fields anywhere on
    // the screen (so no manual product-id entry either).
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('omits the current-context card when no mount is provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_wrap(const ProductSwitchBlockedScreen()));
    await tester.pumpAndSettle();

    expect(find.text('المنتج الحالي'), findsNothing);
    expect(find.text('نوع الرول الحالي'), findsNothing);
  });
}
