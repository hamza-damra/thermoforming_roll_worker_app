import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/api/response_envelope.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';

void main() {
  group('ResponseEnvelope.extractData', () {
    test('returns data on success envelope', () {
      final Object? data = ResponseEnvelope.extractData(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'rollId': 999},
      });
      expect(data, <String, dynamic>{'rollId': 999});
    });

    test('returns null when data is null', () {
      final Object? data = ResponseEnvelope.extractData(<String, dynamic>{
        'success': true,
        'data': null,
      });
      expect(data, isNull);
    });

    test('throws when body is not a map', () {
      expect(
        () => ResponseEnvelope.extractData('not-a-map'),
        throwsFormatException,
      );
    });

    test('throws when success is false', () {
      expect(
        () => ResponseEnvelope.extractData(<String, dynamic>{
          'success': false,
          'error': <String, dynamic>{'code': 'X'},
        }),
        throwsFormatException,
      );
    });
  });

  group('ResponseEnvelope.tryExtractError', () {
    test(
      'parses {success:false, error:{code, message}} into BusinessFailure',
      () {
        final BusinessFailure? f = ResponseEnvelope.tryExtractError(
          <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{
              'code': 'ROLL_BLOCKED',
              'message': 'srv',
            },
          },
          statusCode: 409,
        );
        expect(f, isNotNull);
        expect(f!.code, ErrorCode.rollBlocked);
        expect(f.statusCode, 409);
        expect(f.serverMessage, 'srv');
      },
    );

    test('returns null on success envelope', () {
      final BusinessFailure? f = ResponseEnvelope.tryExtractError(
        <String, dynamic>{'success': true, 'data': null},
      );
      expect(f, isNull);
    });

    test('returns null on non-map body', () {
      expect(ResponseEnvelope.tryExtractError('html'), isNull);
    });

    test(
      'unknown wire code → ErrorCode.unknown but preserves wire string in failure',
      () {
        final BusinessFailure? f = ResponseEnvelope.tryExtractError(
          <String, dynamic>{
            'success': false,
            'error': <String, dynamic>{'code': 'NEW_CODE'},
          },
        );
        expect(f, isNotNull);
        expect(f!.code, ErrorCode.unknown);
      },
    );
  });
}
