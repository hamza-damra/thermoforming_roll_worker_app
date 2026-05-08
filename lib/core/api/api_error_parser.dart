import 'package:dio/dio.dart';

import '../errors/app_failure.dart';
import 'response_envelope.dart';

/// Converts low-level Dio errors / unexpected exceptions into the app's sealed
/// [AppFailure] hierarchy. Repositories should catch [DioException] (and any
/// other thrown error) and call [ApiErrorParser.parse] before returning a
/// failure to the controller layer.
class ApiErrorParser {
  ApiErrorParser._();

  /// Parses any error thrown during an HTTP call.
  static AppFailure parse(Object error, [StackTrace? _]) {
    if (error is DioException) return _fromDio(error);
    return UnknownFailure(cause: error);
  }

  static AppFailure _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkFailure(cause: e);
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
        // fall through to body inspection
        break;
    }

    final Response<dynamic>? response = e.response;
    if (response == null) {
      // No response object — treat as network-level failure.
      return NetworkFailure(cause: e);
    }

    final int statusCode = response.statusCode ?? 0;
    final BusinessFailure? business = ResponseEnvelope.tryExtractError(
      response.data,
      statusCode: statusCode,
    );
    if (business != null) return business;

    return ServerFailure(
      statusCode: statusCode,
      message: response.statusMessage,
    );
  }
}
