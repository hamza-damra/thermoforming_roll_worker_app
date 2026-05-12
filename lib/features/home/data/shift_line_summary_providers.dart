import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/storage/storage_providers.dart';
import '../domain/shift_line_summary_repository.dart';
import 'shift_line_summary_api.dart';
import 'shift_line_summary_repository_impl.dart';

final Provider<ShiftLineSummaryApi> shiftLineSummaryApiProvider =
    Provider<ShiftLineSummaryApi>(
      (ref) => ShiftLineSummaryApi(ref.watch(dioProvider)),
    );

final Provider<ShiftLineSummaryRepository> shiftLineSummaryRepositoryProvider =
    Provider<ShiftLineSummaryRepository>(
      (ref) => ShiftLineSummaryRepositoryImpl(
        api: ref.watch(shiftLineSummaryApiProvider),
        storage: ref.watch(secureTokenStorageProvider),
      ),
    );
