import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/api/api_error_parser.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';

DioException _dioException({
  required DioExceptionType type,
  Response<dynamic>? response,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/x'),
    type: type,
    response: response,
  );
}

Response<dynamic> _response({
  required int statusCode,
  Object? data,
  String? message,
}) {
  return Response<dynamic>(
    requestOptions: RequestOptions(path: '/x'),
    statusCode: statusCode,
    data: data,
    statusMessage: message,
  );
}

void main() {
  group('ApiErrorParser', () {
    test('connectionTimeout → NetworkFailure', () {
      final AppFailure f = ApiErrorParser.parse(
        _dioException(type: DioExceptionType.connectionTimeout),
      );
      expect(f, isA<NetworkFailure>());
    });

    test('connectionError → NetworkFailure', () {
      final AppFailure f = ApiErrorParser.parse(
        _dioException(type: DioExceptionType.connectionError),
      );
      expect(f, isA<NetworkFailure>());
    });

    test('badResponse with envelope → BusinessFailure with mapped code', () {
      final AppFailure f = ApiErrorParser.parse(
        _dioException(
          type: DioExceptionType.badResponse,
          response: _response(
            statusCode: 409,
            data: <String, dynamic>{
              'success': false,
              'error': <String, dynamic>{
                'code': 'ROLL_ALREADY_CONSUMED',
                'message': 'Server-side message',
              },
            },
          ),
        ),
      );
      expect(f, isA<BusinessFailure>());
      final BusinessFailure b = f as BusinessFailure;
      expect(b.code, ErrorCode.rollAlreadyConsumed);
      expect(b.statusCode, 409);
      expect(b.serverMessage, 'Server-side message');
    });

    test('badResponse with unknown code → BusinessFailure(unknown)', () {
      final AppFailure f = ApiErrorParser.parse(
        _dioException(
          type: DioExceptionType.badResponse,
          response: _response(
            statusCode: 400,
            data: <String, dynamic>{
              'success': false,
              'error': <String, dynamic>{'code': 'BRAND_NEW_CODE'},
            },
          ),
        ),
      );
      expect(f, isA<BusinessFailure>());
      expect((f as BusinessFailure).code, ErrorCode.unknown);
    });

    test('badResponse without envelope → ServerFailure', () {
      final AppFailure f = ApiErrorParser.parse(
        _dioException(
          type: DioExceptionType.badResponse,
          response: _response(
            statusCode: 502,
            data: '<html>Bad Gateway</html>',
            message: 'Bad Gateway',
          ),
        ),
      );
      expect(f, isA<ServerFailure>());
      expect((f as ServerFailure).statusCode, 502);
    });

    test('badResponse with no response object → NetworkFailure', () {
      final AppFailure f = ApiErrorParser.parse(
        _dioException(type: DioExceptionType.badResponse),
      );
      expect(f, isA<NetworkFailure>());
    });

    test('arbitrary thrown error → UnknownFailure', () {
      final AppFailure f = ApiErrorParser.parse(StateError('boom'));
      expect(f, isA<UnknownFailure>());
    });
  });
}
