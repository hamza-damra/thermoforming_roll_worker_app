import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../domain/active_shift_line_options_repository.dart';
import 'active_shift_line_options_api.dart';
import 'active_shift_line_options_repository_impl.dart';

final Provider<ActiveShiftLineOptionsApi> activeShiftLineOptionsApiProvider =
    Provider<ActiveShiftLineOptionsApi>(
      (ref) => ActiveShiftLineOptionsApi(ref.watch(dioProvider)),
    );

final Provider<ActiveShiftLineOptionsRepository>
activeShiftLineOptionsRepositoryProvider =
    Provider<ActiveShiftLineOptionsRepository>((ref) {
      return ActiveShiftLineOptionsRepositoryImpl(
        api: ref.watch(activeShiftLineOptionsApiProvider),
      );
    });
