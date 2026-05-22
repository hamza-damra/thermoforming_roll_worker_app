import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import 'dto/roll_worker_bootstrap_response.dart';

/// Thin remote data source for the pre-login bootstrap picker. Throws
/// [DioException] / [FormatException] on transport / HTTP / shape errors —
/// repositories catch and route through `ApiErrorParser`.
class RollWorkerBootstrapApi {
  RollWorkerBootstrapApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/thermoforming-roll-app/bootstrap`.
  ///
  /// Headers: `X-Device-Key` is added by the global interceptor. No
  /// `X-Session-Token` — this endpoint exists precisely to be reachable
  /// before login (the request is not tagged, so the interceptor omits it).
  Future<List<RollWorkerBootstrapLineDto>> fetch() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiPaths.rollWorkerBootstrap,
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    return RollWorkerBootstrapResponse.linesFromEnvelopeData(data);
  }
}
