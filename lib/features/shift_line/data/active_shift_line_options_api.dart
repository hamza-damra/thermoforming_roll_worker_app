import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import 'dto/active_shift_line_option_response.dart';

/// Thin remote data source for the pre-login shift-line picker. Throws
/// [DioException] on transport / HTTP errors — repositories catch and route
/// through `ApiErrorParser`.
class ActiveShiftLineOptionsApi {
  ActiveShiftLineOptionsApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/thermoforming-roll-app/shift-lines/active-options`.
  ///
  /// Headers: `X-Device-Key` is added by the global interceptor. No
  /// `X-Session-Token` — this endpoint exists precisely to be reachable
  /// before login.
  Future<List<ActiveShiftLineOptionResponse>> fetch() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiPaths.activeShiftLineOptions,
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! List) {
      throw const FormatException(
        'shift-lines/active-options: malformed data envelope',
      );
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(ActiveShiftLineOptionResponse.fromJson)
        .toList(growable: false);
  }
}
