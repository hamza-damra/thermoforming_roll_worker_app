import '../../../core/api/api_error_parser.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_code.dart';
import '../../sessions_me/data/sessions_me_token_selector.dart';
import '../domain/entities/manager_announcement.dart';
import '../domain/urgent_announcements_repository.dart';
import 'urgent_announcements_api.dart';

class UrgentAnnouncementsRepositoryImpl implements UrgentAnnouncementsRepository {
  UrgentAnnouncementsRepositoryImpl({
    required UrgentAnnouncementsApi api,
    required SessionsMeTokenSelector tokenSelector,
  }) : _api = api,
       _tokenSelector = tokenSelector;

  final UrgentAnnouncementsApi _api;
  final SessionsMeTokenSelector _tokenSelector;

  @override
  Future<PendingAnnouncementsResult> fetchPending() async {
    final String? token = await _tokenSelector.resolveAnyToken();
    if (token == null || token.isEmpty) {
      // No active session → nothing to fetch. The controller only calls this
      // while logged in, so this is a defensive guard, never the happy path.
      return const PendingAnnouncementsFailure(
        BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      );
    }
    try {
      final List<ManagerAnnouncement> announcements = await _api.fetchPending(
        sessionToken: token,
      );
      return PendingAnnouncementsSuccess(announcements);
    } catch (error, stack) {
      return PendingAnnouncementsFailure(ApiErrorParser.parse(error, stack));
    }
  }

  @override
  Future<AckResult> ack(int id) async {
    final String? token = await _tokenSelector.resolveAnyToken();
    if (token == null || token.isEmpty) {
      return const AckFailure(
        BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
      );
    }
    try {
      await _api.ack(id: id, sessionToken: token);
      return const AckSuccess();
    } catch (error, stack) {
      final AppFailure failure = ApiErrorParser.parse(error, stack);
      // An unknown id means the notice is already gone (acked elsewhere /
      // expired) — the ack is idempotent, so treat it as success and let the
      // modal dismiss safely rather than trapping the worker.
      if (failure is BusinessFailure &&
          failure.code == ErrorCode.rollAnnouncementNotFound) {
        return const AckSuccess();
      }
      return AckFailure(failure);
    }
  }
}
