import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/errors/error_messages_ar.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/screens/scan_roll_screen.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/widgets/roll_scan_blocked_dialog.dart';

BusinessFailure _invalid(String? field, String? reason) => BusinessFailure(
  code: ErrorCode.rollProductionTimeInvalid,
  details: <String, Object?>{
    'field': ?field,
    'reason': ?reason,
  },
);

void main() {
  group('ROLL_PRODUCTION_TIME_INVALID wire mapping', () {
    test('maps from the wire value', () {
      expect(
        ErrorCode.fromWire('ROLL_PRODUCTION_TIME_INVALID'),
        ErrorCode.rollProductionTimeInvalid,
      );
    });
  });

  group('arabicMessageFor(ROLL_PRODUCTION_TIME_INVALID)', () {
    const Map<String, String> fields = <String, String>{
      'year': 'السنة',
      'month': 'الشهر',
      'day': 'اليوم',
      'hour': 'الساعة',
      'minute': 'الدقيقة',
    };

    fields.forEach((String field, String arabic) {
      test('$field REQUIRED names the field', () {
        expect(arabicMessageFor(_invalid(field, 'REQUIRED')), 'أدخل $arabic.');
      });
      test('$field OUT_OF_RANGE names the field', () {
        expect(
          arabicMessageFor(_invalid(field, 'OUT_OF_RANGE')),
          'قيمة $arabic غير صحيحة.',
        );
      });
    });

    test('INVALID_DATE reads as a calendar problem whatever the field', () {
      final String msg = arabicMessageFor(_invalid('day', 'INVALID_DATE'));
      expect(msg, contains('التاريخ غير موجود'));
      expect(arabicMessageFor(_invalid(null, 'INVALID_DATE')), msg);
    });

    test('NONEXISTENT_LOCAL_TIME explains the clock change', () {
      final String msg = arabicMessageFor(
        _invalid('hour', 'NONEXISTENT_LOCAL_TIME'),
      );
      expect(msg, contains('التوقيت الصيفي'));
    });

    test('unknown / missing details fall back to the generic phrasing', () {
      final String generic = arabicForErrorCode(
        ErrorCode.rollProductionTimeInvalid,
      );
      expect(arabicMessageFor(_invalid(null, null)), generic);
      expect(arabicMessageFor(_invalid('weird', 'OUT_OF_RANGE')), generic);
      expect(
        arabicMessageFor(
          const BusinessFailure(code: ErrorCode.rollProductionTimeInvalid),
        ),
        generic,
      );
      expect(generic, isNot(genericRetryArabic));
    });

    test('every message is distinct from the generic retry text', () {
      for (final String field in fields.keys) {
        for (final String reason in <String>[
          'REQUIRED',
          'OUT_OF_RANGE',
          'INVALID_DATE',
          'NONEXISTENT_LOCAL_TIME',
        ]) {
          expect(
            arabicMessageFor(_invalid(field, reason)),
            isNot(genericRetryArabic),
            reason: '$field/$reason',
          );
        }
      }
    });
  });

  group('new ErrorCodes have real Arabic text', () {
    const List<ErrorCode> added = <ErrorCode>[
      ErrorCode.shiftLineAlreadyHasActiveRoll,
      ErrorCode.multipleActiveMountedRollsOnLine,
      ErrorCode.rollGrindingApprovalPending,
      ErrorCode.rollScrapReservedForGrinding,
      ErrorCode.rollProductionTimeInvalid,
    ];

    const Map<ErrorCode, String> wire = <ErrorCode, String>{
      ErrorCode.shiftLineAlreadyHasActiveRoll:
          'SHIFT_LINE_ALREADY_HAS_ACTIVE_ROLL',
      ErrorCode.multipleActiveMountedRollsOnLine:
          'MULTIPLE_ACTIVE_MOUNTED_ROLLS_ON_LINE',
      ErrorCode.rollGrindingApprovalPending: 'ROLL_GRINDING_APPROVAL_PENDING',
      ErrorCode.rollScrapReservedForGrinding:
          'ROLL_SCRAP_RESERVED_FOR_GRINDING',
      ErrorCode.rollProductionTimeInvalid: 'ROLL_PRODUCTION_TIME_INVALID',
    };

    for (final ErrorCode code in added) {
      test(code.wireValue, () {
        expect(code.wireValue, wire[code]);
        expect(ErrorCode.fromWire(wire[code]), code);
        expect(arabicForErrorCode(code), isNot(genericRetryArabic));
        expect(arabicForErrorCode(code), isNotEmpty);
        expect(
          arabicMessageFor(BusinessFailure(code: code)),
          isNot(genericRetryArabic),
        );
      });
    }
  });

  group('rollScanBlockedKindFor', () {
    test('agrees with ScanRollScreen.blockedKindFor for every code', () {
      for (final ErrorCode code in ErrorCode.values) {
        expect(
          rollScanBlockedKindFor(code),
          ScanRollScreen.blockedKindFor(code),
          reason: code.wireValue,
        );
      }
    });

    test('terminal codes map to their dialog kind', () {
      expect(
        rollScanBlockedKindFor(ErrorCode.rollAlreadyConsumed),
        RollScanBlockedKind.consumed,
      );
      expect(
        rollScanBlockedKindFor(ErrorCode.rollSentToGrindingNotReusable),
        RollScanBlockedKind.grinding,
      );
      expect(
        rollScanBlockedKindFor(ErrorCode.rollAdminCancelled),
        RollScanBlockedKind.adminCancelled,
      );
      expect(
        rollScanBlockedKindFor(ErrorCode.rollReconciledOutOfStock),
        RollScanBlockedKind.reconciledOutOfStock,
      );
    });

    test('non-terminal codes have no dialog', () {
      expect(rollScanBlockedKindFor(ErrorCode.rollTypeNotAllowedForProduct), isNull);
      expect(rollScanBlockedKindFor(ErrorCode.shiftLineAlreadyHasActiveRoll), isNull);
      expect(rollScanBlockedKindFor(ErrorCode.unknown), isNull);
    });
  });
}
