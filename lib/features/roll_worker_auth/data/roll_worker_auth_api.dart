import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import 'dto/roll_worker_auth_response.dart';
import 'dto/roll_worker_session_response.dart';

/// Thin remote data source over Dio for the three roll-worker auth
/// endpoints. Throws [DioException] on transport / HTTP errors —
/// repositories are expected to catch and route through `ApiErrorParser`.
class RollWorkerAuthApi {
  RollWorkerAuthApi(this._dio);

  final Dio _dio;

  /// `POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-auth`
  /// with body `{ "pin": "..." }`.
  ///
  /// Headers: `X-Device-Key` is added by the global interceptor. No
  /// `X-Session-Token` (the worker has none yet — that's the point of this
  /// call).
  Future<RollWorkerAuthResponse> login({
    required int shiftLineId,
    required String pin,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiPaths.rollWorkerAuth(shiftLineId),
      data: <String, dynamic>{'pin': pin},
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('roll-worker-auth: malformed data envelope');
    }
    return RollWorkerAuthResponse.fromJson(data);
  }

  /// `GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-session/current`
  ///
  /// Discovery mode — does NOT require `X-Session-Token`. Returns the
  /// session DTO without `sessionToken`.
  Future<RollWorkerSessionResponse> getCurrentSession(int shiftLineId) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiPaths.rollWorkerSessionCurrent(shiftLineId),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'roll-worker-session/current: malformed data envelope',
      );
    }
    return RollWorkerSessionResponse.fromJson(data);
  }

  /// `POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/roll-worker-logout`
  /// with body `{ "sessionToken": "..." }`.
  ///
  /// Token in BODY, not header (mirrors the Palletizing app convention).
  /// Idempotent.
  Future<void> logout({
    required int shiftLineId,
    required String sessionToken,
  }) async {
    await _dio.post<dynamic>(
      ApiPaths.rollWorkerLogout(shiftLineId),
      data: <String, dynamic>{'sessionToken': sessionToken},
    );
  }
}
