import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import 'dto/batch_session_start_response.dart';

/// Thin Dio source for `POST /sessions/start-batch`.
///
/// Throws [DioException] on transport / HTTP errors and
/// [FormatException] on malformed envelopes — the repository catches
/// and routes both through `ApiErrorParser`.
class SessionBatchApi {
  SessionBatchApi(this._dio);

  final Dio _dio;

  Future<BatchSessionStartResponse> startBatch({
    required String pin,
    required Set<int> shiftLineIds,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiPaths.sessionsStartBatch,
      data: <String, dynamic>{
        'pin': pin,
        'shiftLineIds': shiftLineIds.toList(growable: false),
      },
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    if (data is! Map<String, dynamic>) {
      throw const FormatException(
        'sessions/start-batch: malformed data envelope',
      );
    }
    return BatchSessionStartResponse.fromJson(data);
  }
}
