import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import '../../../core/api/session_token_interceptor.dart';
import 'dto/thermoforming_roll_scan_response.dart';

/// Thin remote data source for the scan-roll endpoint. Throws
/// [DioException] on transport / HTTP errors — repositories are expected to
/// catch and route through `ApiErrorParser`.
class RollScanApi {
  RollScanApi(this._dio);

  final Dio _dio;

  /// `POST /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/scan-roll`
  /// with body `{ "generatedRollId": "..." }`.
  ///
  /// Headers: `X-Device-Key` is added by the global interceptor.
  /// `X-Session-Token` is attached via [SessionTokenInterceptor.attach] so
  /// the secret is stripped from `extra` before any other interceptor sees
  /// it.
  Future<ThermoformingRollScanResponse> mountRoll({
    required int shiftLineId,
    required String generatedRollId,
    required String sessionToken,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiPaths.scanRoll(shiftLineId),
      data: <String, dynamic>{'generatedRollId': generatedRollId},
      options: Options(extra: SessionTokenInterceptor.attach(sessionToken)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('scan-roll: malformed data envelope');
    }
    return ThermoformingRollScanResponse.fromJson(data);
  }
}
