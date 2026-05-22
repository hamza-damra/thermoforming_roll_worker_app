import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../domain/roll_worker_bootstrap_repository.dart';
import 'roll_worker_bootstrap_api.dart';
import 'roll_worker_bootstrap_repository_impl.dart';

final Provider<RollWorkerBootstrapApi> rollWorkerBootstrapApiProvider =
    Provider<RollWorkerBootstrapApi>(
      (ref) => RollWorkerBootstrapApi(ref.watch(dioProvider)),
    );

final Provider<RollWorkerBootstrapRepository>
rollWorkerBootstrapRepositoryProvider = Provider<RollWorkerBootstrapRepository>(
  (ref) => RollWorkerBootstrapRepositoryImpl(
    api: ref.watch(rollWorkerBootstrapApiProvider),
  ),
);
