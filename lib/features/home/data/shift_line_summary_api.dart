import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import '../../../core/api/session_token_interceptor.dart';
import 'dto/shift_line_summary_response.dart';

/// Thin remote data source for the shift-line summary endpoint.
///
/// Throws [DioException] on transport / HTTP errors — the repository catches
/// and routes through `ApiErrorParser`.
class ShiftLineSummaryApi {
  ShiftLineSummaryApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/summary`
  ///
  /// Headers: `X-Device-Key` is added by the global interceptor.
  /// `X-Session-Token` is attached via [SessionTokenInterceptor.attach].
  Future<ShiftLineSummaryResponse> fetchSummary({
    required int shiftLineId,
    required String sessionToken,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiPaths.shiftLineSummary(shiftLineId),
      options: Options(extra: SessionTokenInterceptor.attach(sessionToken)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('shift-line-summary: malformed data envelope');
    }
    return ShiftLineSummaryResponse.fromJson(data);
  }
}
