import 'package:dio/dio.dart';

import '../../../core/api/api_paths.dart';
import '../../../core/api/response_envelope.dart';
import '../../../core/api/session_token_interceptor.dart';
import '../domain/entities/manager_announcement.dart';
import 'dto/manager_announcement_response.dart';

/// Thin remote data source for the sanitized urgent-announcements endpoints.
/// Throws [DioException] on transport / HTTP errors — the repository catches
/// and routes through `ApiErrorParser`.
class UrgentAnnouncementsApi {
  UrgentAnnouncementsApi(this._dio);

  final Dio _dio;

  /// `GET /urgent-announcements/pending`. Returns the worker's pending
  /// (not-yet-acked) sanitized announcements, oldest first.
  Future<List<ManagerAnnouncement>> fetchPending({
    required String sessionToken,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiPaths.urgentAnnouncementsPending,
      options: Options(extra: SessionTokenInterceptor.attach(sessionToken)),
    );
    final Object? data = ResponseEnvelope.extractData(response.data);
    return ManagerAnnouncementResponse.listFromEnvelopeData(data);
  }

  /// `POST /urgent-announcements/{id}/ack`. Empty body. Validates the success
  /// envelope; the `data` field is allowed to be absent / null.
  Future<void> ack({required int id, required String sessionToken}) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiPaths.urgentAnnouncementAck(id),
      options: Options(extra: SessionTokenInterceptor.attach(sessionToken)),
    );
    // Throws on a malformed / non-success envelope; the returned `data` is
    // intentionally ignored (ack has no payload).
    ResponseEnvelope.extractData(response.data);
  }
}
