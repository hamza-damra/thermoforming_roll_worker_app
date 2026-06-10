import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import '../../../core/api/session_token_interceptor.dart';
import 'dto/previous_roll_resolution_response.dart';
import 'dto/roll_worker_handover_response.dart';

/// Thin remote data source for the three previous-roll close endpoints.
/// Throws [DioException] on transport / HTTP errors — repositories are
/// expected to catch and route through `ApiErrorParser`.
class PreviousRollApi {
  PreviousRollApi(this._dio);

  final Dio _dio;

  /// `POST .../shift-lines/{shiftLineId}/previous-roll/full-consume`.
  /// No request body.
  Future<PreviousRollResolutionResponse> fullConsume({
    required int shiftLineId,
    required String sessionToken,
  }) {
    return _post(
      path: ApiPaths.previousRollFullConsume(shiftLineId),
      sessionToken: sessionToken,
    );
  }

  /// `POST .../shift-lines/{shiftLineId}/previous-roll/return` with
  /// `{remainingWeightKg}`.
  Future<PreviousRollResolutionResponse> returnRemaining({
    required int shiftLineId,
    required double remainingWeightKg,
    required String sessionToken,
  }) {
    return _post(
      path: ApiPaths.previousRollReturn(shiftLineId),
      sessionToken: sessionToken,
      body: <String, dynamic>{'remainingWeightKg': remainingWeightKg},
    );
  }

  /// `POST .../shift-lines/{shiftLineId}/previous-roll/grinding` with
  /// `{remainingWeightKg}`.
  Future<PreviousRollResolutionResponse> sendToGrinding({
    required int shiftLineId,
    required double remainingWeightKg,
    required String sessionToken,
  }) {
    return _post(
      path: ApiPaths.previousRollGrinding(shiftLineId),
      sessionToken: sessionToken,
      body: <String, dynamic>{'remainingWeightKg': remainingWeightKg},
    );
  }

  /// `POST .../shift-lines/{shiftLineId}/previous-roll/keep-mounted-handover`
  /// with `{remainingWeightKg}`. Credits the current worker their consumed
  /// interval, keeps the roll mounted, and ENDS the current worker's session.
  Future<RollWorkerHandoverResponse> keepMountedHandover({
    required int shiftLineId,
    required double remainingWeightKg,
    required String sessionToken,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiPaths.previousRollKeepMountedHandover(shiftLineId),
      data: <String, dynamic>{'remainingWeightKg': remainingWeightKg},
      options: Options(extra: SessionTokenInterceptor.attach(sessionToken)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'keep-mounted-handover: malformed data envelope',
      );
    }
    return RollWorkerHandoverResponse.fromJson(data);
  }

  Future<PreviousRollResolutionResponse> _post({
    required String path,
    required String sessionToken,
    Map<String, dynamic>? body,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      path,
      data: body,
      options: Options(extra: SessionTokenInterceptor.attach(sessionToken)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('previous-roll: malformed data envelope');
    }
    return PreviousRollResolutionResponse.fromJson(data);
  }
}
