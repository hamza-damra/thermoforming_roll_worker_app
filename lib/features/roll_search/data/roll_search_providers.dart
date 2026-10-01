import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/roll_search_repository.dart';
import 'roll_search_api.dart';
import 'roll_search_repository_impl.dart';

final Provider<RollSearchApi> rollSearchApiProvider = Provider<RollSearchApi>(
  (ref) => RollSearchApi(ref.watch(dioProvider)),
);

final Provider<RollSearchRepository> rollSearchRepositoryProvider =
    Provider<RollSearchRepository>((ref) {
      return RollSearchRepositoryImpl(
        api: ref.watch(rollSearchApiProvider),
        storage: ref.watch(secureTokenStorageProvider),
      );
    });
