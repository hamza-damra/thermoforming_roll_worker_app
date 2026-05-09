import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/label_reprint_repository.dart';
import 'label_reprint_api.dart';
import 'label_reprint_repository_impl.dart';

final Provider<LabelReprintApi> labelReprintApiProvider =
    Provider<LabelReprintApi>((ref) => LabelReprintApi(ref.watch(dioProvider)));

final Provider<LabelReprintRepository> labelReprintRepositoryProvider =
    Provider<LabelReprintRepository>((ref) {
      return LabelReprintRepositoryImpl(
        api: ref.watch(labelReprintApiProvider),
        storage: ref.watch(secureTokenStorageProvider),
      );
    });
