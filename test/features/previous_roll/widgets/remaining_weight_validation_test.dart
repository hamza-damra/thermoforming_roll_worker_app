import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/widgets/remaining_weight_validation.dart';

void main() {
  group('RemainingWeightValidation (0 < weight <= max)', () {
    test('empty / whitespace → "enter weight" message', () {
      expect(RemainingWeightValidation.validate(''), RemainingWeightValidation.empty);
      expect(RemainingWeightValidation.validate('   '), RemainingWeightValidation.empty);
      expect(RemainingWeightValidation.isValid(''), isFalse);
    });

    test('unparseable → "enter weight" message', () {
      expect(RemainingWeightValidation.validate('.'), RemainingWeightValidation.empty);
    });

    test('zero is INVALID (full consumption is the 0 case, not this)', () {
      expect(
        RemainingWeightValidation.validate('0', maxAllowedKg: 100),
        RemainingWeightValidation.mustBePositive,
      );
      expect(
        RemainingWeightValidation.validate('0.000', maxAllowedKg: 100),
        RemainingWeightValidation.mustBePositive,
      );
      expect(RemainingWeightValidation.isValid('0', maxAllowedKg: 100), isFalse);
    });

    test('negative is INVALID', () {
      expect(
        RemainingWeightValidation.validate('-5', maxAllowedKg: 100),
        RemainingWeightValidation.mustBePositive,
      );
    });

    test('above max is INVALID', () {
      expect(
        RemainingWeightValidation.validate('150', maxAllowedKg: 100),
        RemainingWeightValidation.overflow,
      );
    });

    test('0 < value <= max is VALID', () {
      expect(RemainingWeightValidation.validate('0.5', maxAllowedKg: 100), isNull);
      expect(RemainingWeightValidation.validate('100', maxAllowedKg: 100), isNull);
      expect(RemainingWeightValidation.validate('101.000', maxAllowedKg: 101), isNull);
      expect(RemainingWeightValidation.isValid('40', maxAllowedKg: 250), isTrue);
    });

    test('null max skips the upper bound (backend still validates)', () {
      expect(RemainingWeightValidation.validate('99999'), isNull);
      expect(RemainingWeightValidation.validate('0'), RemainingWeightValidation.mustBePositive);
    });
  });
}
