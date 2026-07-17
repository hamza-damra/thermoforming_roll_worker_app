import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/util/roll_status_labels_ar.dart';

void main() {
  group('closedReasonLabelAr', () {
    test('maps every known closedReason wire value to Arabic', () {
      expect(closedReasonLabelAr('FULL_CONSUMPTION'), 'استهلاك كامل');
      expect(closedReasonLabelAr('PARTIAL_RETURN'), 'إرجاع جزئي');
      expect(closedReasonLabelAr('PARTIAL_GRINDING'), 'جرش جزئي');
    });

    test(
      'GRINDING_REJECTED_TO_RETURN renders the exact management-rejection label',
      () {
        expect(
          closedReasonLabelAr('GRINDING_REJECTED_TO_RETURN'),
          'التوصية بالجرش مرفوضة من قبل الإدارة',
        );
      },
    );

    test('unknown / empty values fall back to the safe Arabic label', () {
      expect(closedReasonLabelAr('SOMETHING_NEW'), unknownRollStatusLabelAr);
      expect(closedReasonLabelAr(''), unknownRollStatusLabelAr);
      expect(unknownRollStatusLabelAr, 'حالة غير معروفة');
    });

    test('never echoes a raw wire code back to the operator', () {
      // An unknown value must not leak any part of the raw enum token.
      expect(
        closedReasonLabelAr('GRINDING_REJECTED_TO_RETURN_V2'),
        isNot(contains('GRINDING')),
      );
      expect(closedReasonLabelAr('SOMETHING_NEW'), isNot(contains('_')));
    });
  });

  group('remainderActionLabelAr', () {
    test('maps every known remainderAction wire value to Arabic', () {
      expect(remainderActionLabelAr('NONE'), 'بدون متبقي');
      expect(remainderActionLabelAr('RETURN'), 'إرجاع المتبقي');
      expect(remainderActionLabelAr('GRINDING'), 'إرسال للجرش');
    });

    test('unknown / empty values fall back to the safe Arabic label', () {
      expect(remainderActionLabelAr('OTHER'), unknownRollStatusLabelAr);
      expect(remainderActionLabelAr(''), unknownRollStatusLabelAr);
    });
  });
}
