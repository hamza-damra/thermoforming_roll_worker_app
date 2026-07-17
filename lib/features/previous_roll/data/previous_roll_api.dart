import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import '../../../core/api/session_token_interceptor.dart';
import 'dto/previous_roll_resolution_response.dart';

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
  /// `{remainingWeightKg, reasonText}` (V127 — `reasonText` is now required and
  /// re-validated server-side: trimmed, non-blank, max 500 chars).
  Future<PreviousRollResolutionResponse> returnRemaining({
    required int shiftLineId,
    required double remainingWeightKg,
    required String reasonText,
    required String sessionToken,
  }) {
    return _post(
      path: ApiPaths.previousRollReturn(shiftLineId),
      sessionToken: sessionToken,
      body: <String, dynamic>{
        'remainingWeightKg': remainingWeightKg,
        'reasonText': reasonText.trim(),
      },
    );
  }

  /// `POST .../shift-lines/{shiftLineId}/previous-roll/grinding` with
  /// `{remainingWeightKg, reasonText}` (V127 — `reasonText` is now required).
  Future<PreviousRollResolutionResponse> sendToGrinding({
    required int shiftLineId,
    required double remainingWeightKg,
    required String reasonText,
    required String sessionToken,
  }) {
    return _post(
      path: ApiPaths.previousRollGrinding(shiftLineId),
      sessionToken: sessionToken,
      body: <String, dynamic>{
        'remainingWeightKg': remainingWeightKg,
        'reasonText': reasonText.trim(),
      },
    );
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
