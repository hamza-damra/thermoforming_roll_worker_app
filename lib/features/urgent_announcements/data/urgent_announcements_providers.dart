import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../sessions_me/data/sessions_me_providers.dart';
import '../domain/urgent_announcements_repository.dart';
import 'urgent_announcements_api.dart';
import 'urgent_announcements_repository_impl.dart';

final Provider<UrgentAnnouncementsApi> urgentAnnouncementsApiProvider =
    Provider<UrgentAnnouncementsApi>(
      (ref) => UrgentAnnouncementsApi(ref.watch(dioProvider)),
    );

final Provider<UrgentAnnouncementsRepository>
urgentAnnouncementsRepositoryProvider = Provider<UrgentAnnouncementsRepository>(
  (ref) => UrgentAnnouncementsRepositoryImpl(
    api: ref.watch(urgentAnnouncementsApiProvider),
    // Reuse the shared token selector — the ack is operator-scoped, so any
    // one of the worker's active session tokens is accepted.
    tokenSelector: ref.watch(sessionsMeTokenSelectorProvider),
  ),
);
