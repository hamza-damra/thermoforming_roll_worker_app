import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/biometric_attempt_token.dart';
import '../../../core/api/response_envelope.dart';
import '../domain/entities/biometric_attempt_status.dart';

/// Thin Dio source for the biometric attempt-status long-poll.
///
/// Must be built on `biometricStatusDioProvider`: the endpoint takes no device
/// key and no session token, only the attempt token header, and needs a
/// receive timeout longer than the server's 25 s hold.
///
/// Throws [DioException] on transport / HTTP errors and [FormatException] on
/// a malformed envelope — the repository routes both.
class BiometricAttemptApi {
  BiometricAttemptApi(this._dio);

  final Dio _dio;

  Future<BiometricAttemptStatusResponse> getStatus({
    required String? statusPath,
    required String attemptToken,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      resolveStatusPath(statusPath),
      options: Options(headers: BiometricAttemptToken.header(attemptToken)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'biometric login-attempts/status: malformed data envelope',
      );
    }
    final Object? expiresAt = data['attemptExpiresAt'];
    return BiometricAttemptStatusResponse(
      status: BiometricAttemptStatus.fromWire(data['status']),
      attemptExpiresAt: expiresAt is String
          ? DateTime.tryParse(expiresAt)?.toUtc()
          : null,
    );
  }

  /// Returns [statusPath] when it is a same-origin absolute path, else the
  /// documented [ApiPaths.biometricLoginAttemptStatus].
  ///
  /// The attempt token rides on this request, so a value that would leave the
  /// configured base URL (`https://…`, protocol-relative `//host/…`) or is not
  /// a path at all is never followed.
  static String resolveStatusPath(String? statusPath) {
    if (statusPath == null || !statusPath.startsWith('/')) {
      return ApiPaths.biometricLoginAttemptStatus;
    }
    final Uri? uri = Uri.tryParse(statusPath);
    if (uri == null || uri.hasScheme || uri.hasAuthority) {
      return ApiPaths.biometricLoginAttemptStatus;
    }
    return statusPath;
  }
}
