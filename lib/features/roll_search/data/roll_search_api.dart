import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import '../../../core/api/session_token_interceptor.dart';
import '../domain/entities/production_time_input.dart';
import '../domain/entities/roll_search_outcome.dart';
import 'dto/roll_production_time_search_response.dart';

/// Thin remote data source for the production-time roll search. Throws
/// [DioException] on transport / HTTP errors — the repository routes them
/// through `ApiErrorParser`.
class RollSearchApi {
  RollSearchApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/rolls/by-production-time`
  /// with `year`, `month`, `day`, `hour` (0–23) and `minute`.
  ///
  /// `X-Device-Key` comes from the global interceptor; `X-Session-Token` is
  /// attached through [SessionTokenInterceptor.attach].
  Future<RollSearchOutcome> searchByProductionTime({
    required int shiftLineId,
    required ProductionTimeQuery query,
    required String sessionToken,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiPaths.rollsByProductionTime(shiftLineId),
      queryParameters: query.toQueryParameters(),
      options: Options(extra: SessionTokenInterceptor.attach(sessionToken)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'rolls/by-production-time: malformed data envelope',
      );
    }
    return RollProductionTimeSearchResponse.parse(data);
  }
}
