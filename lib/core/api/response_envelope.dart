import '../errors/app_failure.dart';
import '../errors/biometric_denial.dart';
import '../errors/error_code.dart';
import '../errors/error_messages_ar.dart';

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
  ///
  /// A biometric login refusal (`BIOMETRIC_*`, see
  /// [BiometricDenial.isDenialCode]) comes back as a [BiometricDenialFailure]
  /// — branched on `error.code` only, never on the status, so other 403s keep
  /// their current handling. Its attempt token never lands in a plain
  /// `details` map.
  static BusinessFailure? tryExtractError(Object? body, {int? statusCode}) {
    if (body is! Map<String, dynamic>) return null;
    if (body['success'] == true) return null;

    final Object? error = body['error'];
    if (error is! Map<String, dynamic>) return null;

    final Object? code = error['code'];
    final Object? message = error['message'];
    final Object? rawDetails = error['details'];
    final Map<String, Object?>? details = rawDetails is Map
        ? Map<String, Object?>.from(rawDetails)
        : null;
    if (code is String && BiometricDenial.isDenialCode(code)) {
      return BiometricDenialFailure(
        denial: BiometricDenial.fromEnvelope(
          code: code,
          message: message is String && message.trim().isNotEmpty
              ? message
              : arabicForErrorCode(ErrorCode.fromWire(code)),
          details: details,
        ),
        statusCode: statusCode,
      );
    }
    return BusinessFailure(
      code: ErrorCode.fromWire(code is String ? code : null),
      serverMessage: message is String ? message : null,
      statusCode: statusCode,
      details: details,
    );
  }
}
