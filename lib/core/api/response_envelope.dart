import '../errors/app_failure.dart';
import '../errors/error_code.dart';

/// Backend success envelope: `{ "success": true, "data": <T> }`.
///
/// Use [parseEnvelope] to extract `data` from a decoded JSON map.
/// Failure envelopes are handled by `ApiErrorParser` from [DioException]s
/// — this helper only deals with the success case.
class ResponseEnvelope {
  ResponseEnvelope._();

  /// Returns the `data` field from a success envelope. Throws an
  /// [UnknownFailure]-wrapping [FormatException] if the payload is malformed.
  static Object? extractData(Object? body) {
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Response is not a JSON object.');
    }
    final Object? success = body['success'];
    if (success != true) {
      throw const FormatException('Response envelope missing `success: true`.');
    }
    return body['data'];
  }

  /// Extracts a structured error from a failure envelope:
  /// `{ "success": false, "error": { "code": "...", "message": "..." } }`.
  ///
  /// Returns null if the body is not a failure envelope (caller should fall
  /// back to a [ServerFailure] in that case).
  static BusinessFailure? tryExtractError(Object? body, {int? statusCode}) {
    if (body is! Map<String, dynamic>) return null;
    if (body['success'] == true) return null;

    final Object? error = body['error'];
    if (error is! Map<String, dynamic>) return null;

    final Object? code = error['code'];
    final Object? message = error['message'];
    return BusinessFailure(
      code: ErrorCode.fromWire(code is String ? code : null),
      serverMessage: message is String ? message : null,
      statusCode: statusCode,
    );
  }
}
