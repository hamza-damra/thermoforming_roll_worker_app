import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import '../../../core/api/session_token_interceptor.dart';
import '../../shift_line/data/dto/roll_worker_bootstrap_response.dart';
import '../domain/entities/roll_worker_me.dart';
import 'dto/joinable_lines_response.dart';
import 'dto/roll_worker_me_response.dart';

/// Sentinel thrown by [SessionsMeApi] when no per-line session token is
/// available for the `X-Session-Token` header. The repository routes this
/// to a `BusinessFailure(rollWorkerSessionRequired)` so the controller
/// triggers the picker route.
class SessionsMeNoTokenException implements Exception {
  const SessionsMeNoTokenException();
  @override
  String toString() => 'SessionsMeNoTokenException';
}

/// Thin Dio source for the three unified post-login endpoints. Throws
/// [DioException] on transport / HTTP errors, [FormatException] on
/// malformed envelopes, and [SessionsMeNoTokenException] when the caller
/// did not supply a token (the device has no active sessions).
class SessionsMeApi {
  SessionsMeApi(this._dio);

  final Dio _dio;

  Future<RollWorkerMe> fetchMe({required String? token}) async {
    if (token == null || token.isEmpty) {
      throw const SessionsMeNoTokenException();
    }
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiPaths.sessionsMe,
      options: Options(extra: SessionTokenInterceptor.attach(token)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    return RollWorkerMeResponse.fromEnvelopeData(data);
  }

  Future<List<RollWorkerBootstrapLineDto>> fetchJoinableLines({
    required String? token,
  }) async {
    if (token == null || token.isEmpty) {
      throw const SessionsMeNoTokenException();
    }
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiPaths.sessionsMeJoinableLines,
      options: Options(extra: SessionTokenInterceptor.attach(token)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    return JoinableLinesResponse.fromEnvelopeData(data);
  }

  /// `POST /sessions/leave-all`. Backend returns 204 (empty body); we map
  /// to `void`. 204 with no envelope is a success — do not run the body
  /// through [ResponseEnvelope.extractData].
  Future<void> leaveAll({required String? token}) async {
    if (token == null || token.isEmpty) {
      // No active sessions → already-logged-out; treat as success rather
      // than forcing the caller to handle a special case.
      return;
    }
    await _dio.post<dynamic>(
      ApiPaths.sessionsLeaveAll,
      options: Options(extra: SessionTokenInterceptor.attach(token)),
    );
  }
}
