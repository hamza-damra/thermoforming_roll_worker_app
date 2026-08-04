import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/errors/failure_classification.dart';

BusinessFailure _biz(ErrorCode code, {int? statusCode}) =>
    BusinessFailure(code: code, statusCode: statusCode);

void main() {
  group('isSessionLossCascade', () {
    test('true for session and line-state codes', () {
      for (final ErrorCode code in <ErrorCode>[
        ErrorCode.rollWorkerSessionRequired,
        ErrorCode.rollOpSessionTokenMissing,
        ErrorCode.thermoformingShiftLineNotFound,
        ErrorCode.thermoformingShiftLineNotActive,
      ]) {
        expect(isSessionLossCascade(_biz(code)), isTrue, reason: code.wireValue);
      }
    });

    test(
      'FALSE for a device-key fault — the session is valid and re-login fixes '
      'nothing, so this must never cascade',
      () {
        expect(
          isSessionLossCascade(
            _biz(ErrorCode.authInvalidCredentials, statusCode: 401),
          ),
          isFalse,
        );
      },
    );

    test('false for ordinary business codes', () {
      for (final ErrorCode code in <ErrorCode>[
        ErrorCode.rollNotFound,
        ErrorCode.rollAlreadyConsumed,
        ErrorCode.rollAnnouncementNotFound,
        ErrorCode.operatorPinInvalid,
        ErrorCode.unknown,
      ]) {
        expect(
          isSessionLossCascade(_biz(code)),
          isFalse,
          reason: code.wireValue,
        );
      }
    });

    test('false for non-business failures (transport / server / unknown)', () {
      expect(isSessionLossCascade(const NetworkFailure()), isFalse);
      expect(isSessionLossCascade(const ServerFailure(statusCode: 500)), isFalse);
      expect(isSessionLossCascade(const UnknownFailure()), isFalse);
    });

    test(
      'classification is driven by code, not status — the same code cascades '
      'at 400, 401 and 404',
      () {
        // §4.4: ROLL_WORKER_SESSION_REQUIRED is 400 for a blank token, 404 for
        // an unknown one, 401 for an inactive session. An app that branched on
        // status would mishandle two of the three.
        for (final int status in <int>[400, 401, 404]) {
          expect(
            isSessionLossCascade(
              _biz(ErrorCode.rollWorkerSessionRequired, statusCode: status),
            ),
            isTrue,
            reason: 'status $status',
          );
        }
      },
    );

    test('a 401 alone does not cascade — only the code decides', () {
      // Both flavours arrive as 401. Only one is a session loss.
      expect(
        isSessionLossCascade(
          _biz(ErrorCode.authInvalidCredentials, statusCode: 401),
        ),
        isFalse,
      );
      expect(
        isSessionLossCascade(
          _biz(ErrorCode.rollWorkerSessionRequired, statusCode: 401),
        ),
        isTrue,
      );
    });
  });

  group('isDeviceAuthFault', () {
    test('true only for AUTH_INVALID_CREDENTIALS', () {
      expect(
        isDeviceAuthFault(_biz(ErrorCode.authInvalidCredentials)),
        isTrue,
      );
      for (final ErrorCode code in ErrorCode.values) {
        if (code == ErrorCode.authInvalidCredentials) continue;
        expect(isDeviceAuthFault(_biz(code)), isFalse, reason: code.wireValue);
      }
    });

    test('false for non-business failures', () {
      expect(isDeviceAuthFault(const NetworkFailure()), isFalse);
      expect(isDeviceAuthFault(const ServerFailure(statusCode: 401)), isFalse);
      expect(isDeviceAuthFault(const UnknownFailure()), isFalse);
    });
  });

  test('the two predicates are mutually exclusive for every code', () {
    // The structural guarantee: nothing can be both a device fault and a
    // session loss, so no call site can accidentally log a worker out over a
    // misconfigured device key.
    for (final ErrorCode code in ErrorCode.values) {
      final BusinessFailure f = _biz(code);
      expect(
        isDeviceAuthFault(f) && isSessionLossCascade(f),
        isFalse,
        reason: code.wireValue,
      );
    }
  });
}
