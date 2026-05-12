import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/roll_worker_auth_repository.dart';
import '../domain/session_batch_repository.dart';
import 'roll_worker_auth_api.dart';
import 'roll_worker_auth_repository_impl.dart';
import 'session_batch_api.dart';
import 'session_batch_repository_impl.dart';

final Provider<RollWorkerAuthApi> rollWorkerAuthApiProvider =
    Provider<RollWorkerAuthApi>((ref) {
      return RollWorkerAuthApi(ref.watch(dioProvider));
    });

final Provider<RollWorkerAuthRepository> rollWorkerAuthRepositoryProvider =
    Provider<RollWorkerAuthRepository>((ref) {
      return RollWorkerAuthRepositoryImpl(
        api: ref.watch(rollWorkerAuthApiProvider),
        storage: ref.watch(secureTokenStorageProvider),
      );
    });

final Provider<SessionBatchApi> sessionBatchApiProvider =
    Provider<SessionBatchApi>((ref) {
      return SessionBatchApi(ref.watch(dioProvider));
    });

final Provider<SessionBatchRepository> sessionBatchRepositoryProvider =
    Provider<SessionBatchRepository>((ref) {
      return SessionBatchRepositoryImpl(
        api: ref.watch(sessionBatchApiProvider),
        tokenStorage: ref.watch(secureTokenStorageProvider),
        indexStorage: ref.watch(sessionIndexStorageProvider),
      );
    });
