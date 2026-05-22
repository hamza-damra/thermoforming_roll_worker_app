import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/takeover_countdown.dart';

void main() {
  testWidgets('renders mm:ss and fires onExpired exactly once at zero',
      (WidgetTester tester) async {
    int expiredCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TakeoverCountdown(
            // Already past → the next tick crosses zero.
            target: DateTime.now().subtract(const Duration(seconds: 1)),
            window: const Duration(minutes: 10),
            onExpired: () => expiredCalls++,
          ),
        ),
      ),
    );

    // A past target clamps to 00:00.
    expect(find.text('00:00'), findsOneWidget);
    expect(expiredCalls, 0);

    // First 1-second tick crosses zero and fires the callback.
    await tester.pump(const Duration(seconds: 1));
    expect(expiredCalls, 1);

    // Subsequent ticks must not replay the callback.
    await tester.pump(const Duration(seconds: 1));
    expect(expiredCalls, 1);
  });
}
