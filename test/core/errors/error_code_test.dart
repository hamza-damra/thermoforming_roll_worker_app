import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/errors/error_messages_ar.dart';

void main() {
  group('ErrorCode', () {
    test('fromWire matches every documented code', () {
      const Map<String, ErrorCode> wireToEnum = <String, ErrorCode>{
        'ROLL_WORKER_NOT_ALLOWED': ErrorCode.rollWorkerNotAllowed,
        'ROLL_WORKER_SESSION_REQUIRED': ErrorCode.rollWorkerSessionRequired,
        'OPERATOR_PIN_INVALID': ErrorCode.operatorPinInvalid,
        'OPERATOR_PIN_LOCKED': ErrorCode.operatorPinLocked,
        'THERMOFORMING_SHIFT_LINE_NOT_FOUND':
            ErrorCode.thermoformingShiftLineNotFound,
        'THERMOFORMING_SHIFT_LINE_NOT_ACTIVE':
            ErrorCode.thermoformingShiftLineNotActive,
        'NO_CURRENT_PRODUCT_ON_LINE': ErrorCode.noCurrentProductOnLine,
        'ROLL_NOT_FOUND': ErrorCode.rollNotFound,
        'ROLL_ALREADY_CONSUMED': ErrorCode.rollAlreadyConsumed,
        'ROLL_ACTIVE_ON_ANOTHER_LINE': ErrorCode.rollActiveOnAnotherLine,
        'ROLL_BLOCKED': ErrorCode.rollBlocked,
        'ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT':
            ErrorCode.rollTypeNotAllowedForProduct,
        'ROLL_CURING_MINIMUM_NOT_MET': ErrorCode.rollCuringMinimumNotMet,
        'NO_ACTIVE_ROLL_ON_LINE': ErrorCode.noActiveRollOnLine,
        'NO_OPEN_SEGMENT_ON_ITEM': ErrorCode.noOpenSegmentOnItem,
        'INVALID_REMAINING_ROLL_WEIGHT': ErrorCode.invalidRemainingRollWeight,
        'CURRENT_ROLL_WEIGHT_REQUIRED': ErrorCode.currentRollWeightRequired,
        'INVALID_CURRENT_ROLL_WEIGHT': ErrorCode.invalidCurrentRollWeight,
        'PRODUCT_TYPE_NOT_FOUND': ErrorCode.productTypeNotFound,
        'PRODUCT_TYPE_INACTIVE': ErrorCode.productTypeInactive,
        'ROLL_LABEL_REPRINT_NOT_AVAILABLE':
            ErrorCode.rollLabelReprintNotAvailable,
        'VALIDATION_ERROR': ErrorCode.validationError,
      };
      wireToEnum.forEach((String wire, ErrorCode expected) {
        expect(ErrorCode.fromWire(wire), expected, reason: wire);
      });
    });

    test('fromWire returns unknown for unrecognised codes', () {
      expect(ErrorCode.fromWire('SOMETHING_NEW'), ErrorCode.unknown);
      expect(ErrorCode.fromWire(''), ErrorCode.unknown);
      expect(ErrorCode.fromWire(null), ErrorCode.unknown);
    });

    test('fromWire is case-sensitive (matches backend exactly)', () {
      expect(ErrorCode.fromWire('roll_worker_not_allowed'), ErrorCode.unknown);
    });
  });

  group('arabicMessageFor', () {
    test('NetworkFailure → connectivity Arabic banner copy', () {
      expect(arabicMessageFor(const NetworkFailure()), noConnectionArabic);
    });

    test('BusinessFailure with known code → mapped Arabic', () {
      expect(
        arabicMessageFor(
          const BusinessFailure(code: ErrorCode.rollAlreadyConsumed),
        ),
        'تم استهلاك هذا الرول بالفعل ولا يمكن تحميله مرة أخرى.',
      );
      expect(
        arabicMessageFor(
          const BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
        ),
        'انتهت الجلسة، يُرجى تسجيل الدخول مجددًا.',
      );
    });

    test('BusinessFailure with unknown code → generic Arabic', () {
      expect(
        arabicMessageFor(const BusinessFailure(code: ErrorCode.unknown)),
        genericRetryArabic,
      );
    });

    test('ServerFailure → generic Arabic', () {
      expect(
        arabicMessageFor(const ServerFailure(statusCode: 500)),
        genericRetryArabic,
      );
    });

    test('UnknownFailure → generic Arabic', () {
      expect(arabicMessageFor(const UnknownFailure()), genericRetryArabic);
    });

    test('every non-unknown ErrorCode has a non-generic Arabic message', () {
      for (final ErrorCode code in ErrorCode.values) {
        if (code == ErrorCode.unknown) continue;
        // VALIDATION_ERROR intentionally maps to the generic Arabic per spec.
        if (code == ErrorCode.validationError) continue;
        expect(
          arabicForErrorCode(code),
          isNot(genericRetryArabic),
          reason: 'Missing Arabic mapping for ${code.wireValue}',
        );
      }
    });
  });
}
