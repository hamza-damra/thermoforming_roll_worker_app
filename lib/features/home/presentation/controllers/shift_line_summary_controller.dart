import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../data/shift_line_summary_providers.dart';
import '../../domain/shift_line_summary_repository.dart';
import 'shift_line_summary_state.dart';

class ShiftLineSummaryController
    extends FamilyNotifier<ShiftLineSummaryState, int> {
  late int _shiftLineId;

  @override
  ShiftLineSummaryState build(int arg) {
    _shiftLineId = arg;
    return const SummaryLoading();
  }

  ShiftLineSummaryRepository get _repo =>
      ref.read(shiftLineSummaryRepositoryProvider);

  /// Full load for first paint. Transitions through [SummaryLoading].
  Future<void> load() async {
    state = const SummaryLoading();
    await _doFetch();
  }

  /// Background refresh — keeps existing data visible while re-fetching.
  ///
  /// If a [SummaryLoaded] state exists, it remains displayed with
  /// [SummaryLoaded.isRefreshing] set to `true`. Hard [SummaryError] only
  /// occurs on a first-load failure when no prior data is available.
  Future<void> refresh() async {
    final ShiftLineSummaryState current = state;
    if (current is SummaryLoaded) {
      state = current.copyWith(isRefreshing: true);
    } else {
      state = const SummaryLoading();
    }
    await _doFetch();
  }

  Future<void> _doFetch() async {
    final SummaryResult result = await _repo.fetchSummary(
      shiftLineId: _shiftLineId,
    );
    switch (result) {
      case SummarySuccess(:final summary):
        state = SummaryLoaded(summary);
      case SummaryFailure(:final failure):
        await _onFailure(failure);
    }
  }

  Future<void> _onFailure(AppFailure failure) async {
    final ShiftLineSummaryState current = state;
    if (current is SummaryLoaded) {
      // Drop the refreshing flag; keep showing last good data.
      state = current.copyWith(isRefreshing: false);
    } else {
      state = SummaryError(failure);
    }
    if (failure is BusinessFailure) {
      switch (failure.code) {
        case ErrorCode.rollWorkerSessionRequired:
        case ErrorCode.thermoformingShiftLineNotActive:
        case ErrorCode.thermoformingShiftLineNotFound:
          await ref
              .read(multiLineSessionRegistryProvider.notifier)
              .notifySessionLost(_shiftLineId);
        default:
          break;
      }
    }
  }
}

final shiftLineSummaryControllerProvider = NotifierProvider.family<
  ShiftLineSummaryController,
  ShiftLineSummaryState,
  int
>(ShiftLineSummaryController.new);
