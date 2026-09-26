import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/api/api_error_parser.dart';
import 'package:thermoforming_roll_worker/core/api/response_envelope.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/biometric_denial.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/errors/error_messages_ar.dart';
import 'package:thermoforming_roll_worker/core/errors/failure_classification.dart';

const String _token = 'q3Jx8d6cYt0H1m0yF3kZ0wS9gQx8B7nV2rP5aL4eK1c';
const String _statusPath = '/api/v1/auth/biometric/login-attempts/status';
const String _requiredMessage =
    'يرجى تمرير البصمة على جهاز البصمة ثم إعادة المحاولة.';

Map<String, dynamic> _envelope(
  String code, {
  String? message,
  Map<String, Object?>? details,
}) => <String, dynamic>{
  'success': false,
  'error': <String, dynamic>{
    'code': code,
    'message': ?message,
    'details': ?details,
  },
};

Map<String, Object?> _withToken() => <String, Object?>{
  'validitySeconds': 300,
  'attemptToken': _token,
  'attemptExpiresAt': '2026-09-24T08:15:00.000Z',
  'statusPath': _statusPath,
  'attemptAvailable': true,
};

const Map<String, Object?> _noToken = <String, Object?>{
  'validitySeconds': 300,
  'attemptAvailable': false,
};

BusinessFailure? _parse(
  String code, {
  String? message,
  Map<String, Object?>? details,
  int statusCode = 403,
}) => ResponseEnvelope.tryExtractError(
  _envelope(code, message: message, details: details),
  statusCode: statusCode,
);

void main() {
  group('ErrorCode — biometric codes (§4.4)', () {
    test('fromWire resolves every documented code', () {
      const Map<String, ErrorCode> wireToEnum = <String, ErrorCode>{
        'BIOMETRIC_VERIFICATION_REQUIRED':
            ErrorCode.biometricVerificationRequired,
        'BIOMETRIC_VERIFICATION_EXPIRED':
            ErrorCode.biometricVerificationExpired,
        'BIOMETRIC_DEVICE_UNAVAILABLE': ErrorCode.biometricDeviceUnavailable,
        'BIOMETRIC_MAPPING_MISSING': ErrorCode.biometricMappingMissing,
        'BIOMETRIC_MAPPING_DISABLED': ErrorCode.biometricMappingDisabled,
        'BIOMETRIC_LOGIN_ATTEMPT_EXPIRED':
            ErrorCode.biometricLoginAttemptExpired,
      };
      wireToEnum.forEach((String wire, ErrorCode expected) {
        expect(ErrorCode.fromWire(wire), expected, reason: wire);
      });
    });

    test('Arabic fallbacks are the server messages verbatim (§10)', () {
      expect(
        arabicForErrorCode(ErrorCode.biometricVerificationRequired),
        _requiredMessage,
      );
      expect(
        arabicForErrorCode(ErrorCode.biometricVerificationExpired),
        'انتهت صلاحية التحقق بالبصمة. يرجى تمرير البصمة مرة أخرى ثم إعادة المحاولة.',
      );
      expect(
        arabicForErrorCode(ErrorCode.biometricDeviceUnavailable),
        'جهاز البصمة غير متصل حاليًا. يرجى المحاولة بعد قليل أو إبلاغ المسؤول.',
      );
      expect(
        arabicForErrorCode(ErrorCode.biometricMappingMissing),
        'لم يتم ربط بصمتك بحسابك بعد. يرجى مراجعة مسؤول النظام.',
      );
      expect(
        arabicForErrorCode(ErrorCode.biometricMappingDisabled),
        'ربط البصمة الخاص بحسابك غير مفعّل. يرجى مراجعة مسؤول النظام.',
      );
      expect(
        arabicForErrorCode(ErrorCode.biometricLoginAttemptExpired),
        'انتهت مهلة محاولة الدخول. يرجى تسجيل الدخول مرة أخرى.',
      );
    });

    test('biometric refusals are never a session loss or device fault', () {
      final BusinessFailure failure = _parse(
        'BIOMETRIC_VERIFICATION_REQUIRED',
        details: _withToken(),
      )!;
      expect(isSessionLossCascade(failure), isFalse);
      expect(isDeviceAuthFault(failure), isFalse);
    });
  });

  group('403 envelope → BiometricDenialFailure', () {
    test('recoverable, token present', () {
      final BusinessFailure? failure = _parse(
        'BIOMETRIC_VERIFICATION_REQUIRED',
        message: _requiredMessage,
        details: _withToken(),
      );

      expect(failure, isA<BiometricDenialFailure>());
      final BiometricDenial denial = (failure! as BiometricDenialFailure).denial;
      expect(failure.code, ErrorCode.biometricVerificationRequired);
      expect(failure.statusCode, 403);
      expect(denial.code, 'BIOMETRIC_VERIFICATION_REQUIRED');
      expect(denial.message, _requiredMessage);
      expect(denial.validitySeconds, 300);
      expect(denial.attemptAvailable, isTrue);
      expect(denial.attemptToken, _token);
      expect(denial.statusPath, _statusPath);
      expect(denial.attemptExpiresAt, DateTime.utc(2026, 9, 24, 8, 15));
      expect(denial.attemptExpiresAt!.isUtc, isTrue);
      expect(denial.hasAttempt, isTrue);
      expect(denial.isMappingProblem, isFalse);
      expect(denial.isDeviceUnavailable, isFalse);
    });

    test('EXPIRED and DEVICE_UNAVAILABLE share the same details shape', () {
      for (final String code in <String>[
        'BIOMETRIC_VERIFICATION_EXPIRED',
        'BIOMETRIC_DEVICE_UNAVAILABLE',
      ]) {
        final BiometricDenial denial =
            (_parse(code, message: 'm', details: _withToken())!
                    as BiometricDenialFailure)
                .denial;
        expect(denial.hasAttempt, isTrue, reason: code);
        expect(denial.attemptToken, _token, reason: code);
      }
      final BiometricDenial offline =
          (_parse('BIOMETRIC_DEVICE_UNAVAILABLE', details: _withToken())!
                  as BiometricDenialFailure)
              .denial;
      expect(offline.isDeviceUnavailable, isTrue);
    });

    test('recoverable, but no attempt could be recorded (token absent)', () {
      final BiometricDenial denial =
          (_parse(
                    'BIOMETRIC_VERIFICATION_REQUIRED',
                    message: _requiredMessage,
                    details: _noToken,
                  )!
                  as BiometricDenialFailure)
              .denial;
      expect(denial.attemptAvailable, isFalse);
      expect(denial.attemptToken, isNull);
      expect(denial.hasAttempt, isFalse);
      expect(denial.isMappingProblem, isFalse);
    });

    test('MAPPING_MISSING / MAPPING_DISABLED are admin-only, never polled', () {
      for (final String code in <String>[
        'BIOMETRIC_MAPPING_MISSING',
        'BIOMETRIC_MAPPING_DISABLED',
      ]) {
        final BiometricDenial denial =
            (_parse(code, message: 'm', details: _noToken)!
                    as BiometricDenialFailure)
                .denial;
        expect(denial.isMappingProblem, isTrue, reason: code);
        expect(denial.hasAttempt, isFalse, reason: code);
      }
    });

    test('a mapping code never polls even if a token slipped through', () {
      final BiometricDenial denial =
          (_parse('BIOMETRIC_MAPPING_MISSING', details: _withToken())!
                  as BiometricDenialFailure)
              .denial;
      expect(denial.hasAttempt, isFalse);
    });

    test('an unknown future BIOMETRIC_* code still opens the dialog', () {
      final BusinessFailure? failure = _parse(
        'BIOMETRIC_SOMETHING_NEW',
        message: 'رسالة',
        details: _withToken(),
      );
      expect(failure, isA<BiometricDenialFailure>());
      expect(failure!.code, ErrorCode.unknown);
      expect((failure as BiometricDenialFailure).denial.hasAttempt, isTrue);
    });

    test('a missing message falls back to the verbatim server copy', () {
      final BiometricDenial denial =
          (_parse('BIOMETRIC_VERIFICATION_REQUIRED', details: _noToken)!
                  as BiometricDenialFailure)
              .denial;
      expect(denial.message, _requiredMessage);
    });

    test('malformed details collapse to safe defaults', () {
      final BiometricDenial denial =
          (_parse(
                    'BIOMETRIC_VERIFICATION_REQUIRED',
                    details: <String, Object?>{
                      'validitySeconds': 'x',
                      'attemptToken': '',
                      'attemptExpiresAt': 'not-a-date',
                      'statusPath': 7,
                    },
                  )!
                  as BiometricDenialFailure)
              .denial;
      expect(denial.validitySeconds, 0);
      expect(denial.attemptToken, isNull);
      expect(denial.attemptAvailable, isFalse);
      expect(denial.attemptExpiresAt, isNull);
      expect(denial.statusPath, isNull);
      expect(denial.hasAttempt, isFalse);
    });

    test('also parsed from a real DioException via ApiErrorParser', () {
      final AppFailure failure = ApiErrorParser.parse(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 403,
            data: _envelope(
              'BIOMETRIC_VERIFICATION_REQUIRED',
              message: _requiredMessage,
              details: _withToken(),
            ),
          ),
        ),
      );
      expect(failure, isA<BiometricDenialFailure>());
    });
  });

  group('everything else keeps its current handling', () {
    test('non-biometric 403 stays a plain BusinessFailure', () {
      final BusinessFailure? failure = _parse(
        'ROLL_WORKER_NOT_ALLOWED',
        details: <String, Object?>{'x': 1},
      );
      expect(failure, isNot(isA<BiometricDenialFailure>()));
      expect(failure!.code, ErrorCode.rollWorkerNotAllowed);
      expect(failure.details, <String, Object?>{'x': 1});
    });

    test('the 410 status code is a plain BusinessFailure, not a denial', () {
      final BusinessFailure? failure = _parse(
        'BIOMETRIC_LOGIN_ATTEMPT_EXPIRED',
        statusCode: 410,
      );
      expect(failure, isNot(isA<BiometricDenialFailure>()));
      expect(failure!.code, ErrorCode.biometricLoginAttemptExpired);
    });
  });

  group('the attempt token is a secret', () {
    test('it never reaches BusinessFailure.details or any toString', () {
      final BiometricDenialFailure failure =
          _parse(
                'BIOMETRIC_VERIFICATION_REQUIRED',
                message: _requiredMessage,
                details: _withToken(),
              )!
              as BiometricDenialFailure;

      expect(failure.details, isNull);
      expect(failure.toString(), isNot(contains(_token)));
      expect(failure.denial.toString(), isNot(contains(_token)));
      expect(failure.denial.toString(), contains('<redacted>'));
    });

    test('withoutAttempt() drops the token', () {
      final BiometricDenial denial =
          (_parse('BIOMETRIC_VERIFICATION_REQUIRED', details: _withToken())!
                  as BiometricDenialFailure)
              .denial
              .withoutAttempt();
      expect(denial.attemptToken, isNull);
      expect(denial.hasAttempt, isFalse);
    });
  });

  group('arabicMessageFor', () {
    test('shows the server message verbatim for every 403 code', () {
      const String serverWording = 'رسالة من الخادم كما هي';
      for (final String code in <String>[
        'BIOMETRIC_VERIFICATION_REQUIRED',
        'BIOMETRIC_VERIFICATION_EXPIRED',
        'BIOMETRIC_DEVICE_UNAVAILABLE',
        'BIOMETRIC_MAPPING_MISSING',
        'BIOMETRIC_MAPPING_DISABLED',
      ]) {
        expect(
          arabicMessageFor(
            _parse(code, message: serverWording, details: _noToken)!,
          ),
          serverWording,
          reason: code,
        );
      }
    });
  });
}
