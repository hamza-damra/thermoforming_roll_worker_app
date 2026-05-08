import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/roll_scan_repository.dart';
import 'roll_scan_api.dart';
import 'roll_scan_repository_impl.dart';

final Provider<RollScanApi> rollScanApiProvider = Provider<RollScanApi>(
  (ref) => RollScanApi(ref.watch(dioProvider)),
);

final Provider<RollScanRepository> rollScanRepositoryProvider =
    Provider<RollScanRepository>((ref) {
      return RollScanRepositoryImpl(
        api: ref.watch(rollScanApiProvider),
        storage: ref.watch(secureTokenStorageProvider),
      );
    });
