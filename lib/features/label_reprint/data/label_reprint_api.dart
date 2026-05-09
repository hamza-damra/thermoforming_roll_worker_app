import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import '../../../core/api/session_token_interceptor.dart';
import 'dto/roll_label_reprint_response.dart';

/// Thin remote data source for the reprint endpoint. Throws
/// [DioException] on transport / HTTP errors — repositories are expected
/// to catch and route through `ApiErrorParser`.
class LabelReprintApi {
  LabelReprintApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/thermoforming-roll-app/rolls/{generatedRollId}/reprint-label`.
  Future<RollLabelReprintResponse> fetchLabel({
    required String generatedRollId,
    required String sessionToken,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiPaths.reprintRollLabel(generatedRollId),
      options: Options(extra: SessionTokenInterceptor.attach(sessionToken)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('reprint-label: malformed data envelope');
    }
    return RollLabelReprintResponse.fromJson(data);
  }
}
