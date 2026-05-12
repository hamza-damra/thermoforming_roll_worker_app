import 'error_code.dart';

/// Sealed failure model. Every API call result is either `data` or one of
/// these failures. Controllers map failures into Arabic messages via
/// [arabicMessageFor] (see `error_messages_ar.dart`).
sealed class AppFailure {
  const AppFailure();
}

/// Network unreachable, DNS failure, timeout, etc. — i.e. the server was
/// never reached or did not respond. UI: connectivity banner + retry.
class NetworkFailure extends AppFailure {
  const NetworkFailure({this.cause});

  final Object? cause;

  @override
  String toString() => 'NetworkFailure(cause: $cause)';
}

/// Server returned a response but it was not a recognised business error
/// (e.g. 5xx without our envelope, or malformed payload). UI: generic Arabic
/// retry.
class ServerFailure extends AppFailure {
  const ServerFailure({required this.statusCode, this.message});

  final int statusCode;
  final String? message;

  @override
  String toString() =>
      'ServerFailure(statusCode: $statusCode, message: $message)';
}

/// Backend returned `{success:false, error:{code, message}}`. The [code] drives
/// UX (clear token? show inline? route back?). [serverMessage] is preserved
/// only for debugging; the user-facing text always comes from the Arabic
/// mapper.
class BusinessFailure extends AppFailure {
  const BusinessFailure({
    required this.code,
    this.serverMessage,
    this.statusCode,
    this.details,
  });

  final ErrorCode code;
  final String? serverMessage;
  final int? statusCode;

  /// Free-form structured payload from `error.details` in the failure
  /// envelope. Carries per-line ids for batch-start conflicts
  /// (e.g. `details.shiftLineId`, `details.ownerOperatorName`). Null when
  /// the backend did not include a `details` block.
  final Map<String, Object?>? details;

  @override
  String toString() =>
      'BusinessFailure(code: ${code.wireValue}, '
      'statusCode: $statusCode, serverMessage: $serverMessage, '
      'details: $details)';
}

/// Anything else (parsing errors, unexpected exceptions). UI: generic Arabic.
class UnknownFailure extends AppFailure {
  const UnknownFailure({this.cause});

  final Object? cause;

  @override
  String toString() => 'UnknownFailure(cause: $cause)';
}
