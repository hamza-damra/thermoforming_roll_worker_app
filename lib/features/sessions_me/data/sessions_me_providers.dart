import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/sessions_me_repository.dart';
import 'sessions_me_api.dart';
import 'sessions_me_repository_impl.dart';
import 'sessions_me_token_selector.dart';

final Provider<SessionsMeApi> sessionsMeApiProvider = Provider<SessionsMeApi>(
  (ref) => SessionsMeApi(ref.watch(dioProvider)),
);

final Provider<SessionsMeTokenSelector> sessionsMeTokenSelectorProvider =
    Provider<SessionsMeTokenSelector>(
      (ref) => SessionsMeTokenSelector(
        tokenStorage: ref.watch(secureTokenStorageProvider),
        indexStorage: ref.watch(sessionIndexStorageProvider),
      ),
    );

final Provider<SessionsMeRepository> sessionsMeRepositoryProvider =
    Provider<SessionsMeRepository>(
      (ref) => SessionsMeRepositoryImpl(
        api: ref.watch(sessionsMeApiProvider),
        tokenSelector: ref.watch(sessionsMeTokenSelectorProvider),
        tokenStorage: ref.watch(secureTokenStorageProvider),
        indexStorage: ref.watch(sessionIndexStorageProvider),
      ),
    );
