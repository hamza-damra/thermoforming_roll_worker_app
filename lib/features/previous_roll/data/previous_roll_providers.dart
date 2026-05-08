import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/previous_roll_repository.dart';
import 'previous_roll_api.dart';
import 'previous_roll_repository_impl.dart';

final Provider<PreviousRollApi> previousRollApiProvider =
    Provider<PreviousRollApi>((ref) => PreviousRollApi(ref.watch(dioProvider)));

final Provider<PreviousRollRepository> previousRollRepositoryProvider =
    Provider<PreviousRollRepository>((ref) {
      return PreviousRollRepositoryImpl(
        api: ref.watch(previousRollApiProvider),
        storage: ref.watch(secureTokenStorageProvider),
      );
    });
