import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/previous_roll/presentation/widgets/reason_text_validation.dart';

void main() {
  group('ReasonTextValidation.validate', () {
    test('empty string is required', () {
      expect(ReasonTextValidation.validate(''), 'السبب مطلوب');
      expect(ReasonTextValidation.isValid(''), isFalse);
    });

    test('whitespace-only is rejected (trimmed)', () {
      expect(ReasonTextValidation.validate('   '), 'السبب مطلوب');
      expect(ReasonTextValidation.validate('\n\t '), 'السبب مطلوب');
      expect(ReasonTextValidation.isValid('   '), isFalse);
    });

    test('a non-blank reason is valid', () {
      expect(ReasonTextValidation.validate('سبب واضح'), isNull);
      expect(ReasonTextValidation.isValid('سبب واضح'), isTrue);
    });

    test('exactly 500 chars is valid', () {
      final String text = 'ط' * 500;
      expect(text.length, 500);
      expect(ReasonTextValidation.validate(text), isNull);
    });

    test('over 500 chars (after trim) is too long', () {
      final String text = 'ط' * 501;
      expect(
        ReasonTextValidation.validate(text),
        'الحد الأقصى 500 حرف.',
      );
      expect(ReasonTextValidation.isValid(text), isFalse);
    });

    test('trailing whitespace does not count toward the limit', () {
      final String text = '${'ط' * 500}        ';
      // 500 real chars + trailing spaces → trims to 500 → valid.
      expect(ReasonTextValidation.validate(text), isNull);
    });
  });
}
