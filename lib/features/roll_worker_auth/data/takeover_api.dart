import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import 'dto/roll_worker_takeover_request.dart';
import 'dto/roll_worker_takeover_response.dart';

/// Thin Dio source for `POST /sessions/takeover-with-roll-declaration`.
///
/// X-Device-Key only — NO session token; the incoming worker is not
/// authenticated yet and the PIN travels in the body. Throws [DioException] on
/// transport / HTTP errors and [FormatException] on malformed envelopes — the
/// repository catches and routes both through `ApiErrorParser`.
class TakeoverApi {
  TakeoverApi(this._dio);

  final Dio _dio;

  Future<RollWorkerTakeoverResponse> takeover(
    RollWorkerTakeoverRequest request,
  ) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiPaths.sessionsTakeoverWithRollDeclaration,
      data: request.toJson(),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'takeover-with-roll-declaration: malformed data envelope',
      );
    }
    return RollWorkerTakeoverResponse.fromJson(data);
  }
}
