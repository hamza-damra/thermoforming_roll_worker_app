import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/allowed_roll.dart';

void main() {
  group('formatAllowedRollDisplayName', () {
    test('backend displayName → base + Arabic category in parentheses', () {
      const roll = AllowedRoll(
        id: 1,
        code: 'TP-6',
        name: 'زبدية',
        colorName: 'Black',
        displayName: 'TP-6 Black / زبدية',
      );
      expect(formatAllowedRollDisplayName(roll), 'TP-6 Black (زبدية)');
    });

    test('production shape where code already carries the colour does NOT '
        'duplicate it', () {
      // Reproduces the `TP-1 Black Black` bug: code already ends with the
      // colour and there is no displayName to fall back on.
      const roll = AllowedRoll(
        id: 2,
        code: 'TP-1 Black',
        name: 'زبدية',
        colorName: 'Black',
      );
      expect(formatAllowedRollDisplayName(roll), 'TP-1 Black (زبدية)');
    });

    test('duplicate colour with no Arabic category collapses to a single '
        'colour', () {
      const black = AllowedRoll(id: 3, code: 'TP-1 Black', colorName: 'Black');
      const white = AllowedRoll(id: 4, code: 'TP-1 White', colorName: 'White');
      const yellow =
          AllowedRoll(id: 5, code: 'TP-1 Yellow', colorName: 'Yellow');
      expect(formatAllowedRollDisplayName(black), 'TP-1 Black');
      expect(formatAllowedRollDisplayName(white), 'TP-1 White');
      expect(formatAllowedRollDisplayName(yellow), 'TP-1 Yellow');
    });

    test('a duplicate baked into displayName itself is also collapsed', () {
      const roll = AllowedRoll(id: 6, displayName: 'TP-2 Black Black');
      expect(formatAllowedRollDisplayName(roll), 'TP-2 Black');
    });

    test('an English category equal to the colour is not appended', () {
      const roll = AllowedRoll(
        id: 7,
        code: 'TP-1 Black',
        colorName: 'Black',
        name: 'Black',
      );
      expect(formatAllowedRollDisplayName(roll), 'TP-1 Black');
    });

    test('code + separate colour (no overlap) is joined once', () {
      const roll = AllowedRoll(id: 8, code: 'TP-1', colorName: 'Blue');
      expect(formatAllowedRollDisplayName(roll), 'TP-1 Blue');
    });

    test('fully empty roll falls back to the placeholder (no crash)', () {
      const roll = AllowedRoll(id: 9);
      expect(formatAllowedRollDisplayName(roll), AllowedRoll.unknownLabel);
    });

    test('only a code is available', () {
      const roll = AllowedRoll(id: 10, code: 'TP-9');
      expect(formatAllowedRollDisplayName(roll), 'TP-9');
    });
  });
}
