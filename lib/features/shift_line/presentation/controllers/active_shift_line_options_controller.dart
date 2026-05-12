import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/active_shift_line_options_providers.dart';
import '../../domain/active_shift_line_options_repository.dart';
import '../../domain/entities/active_shift_line_option.dart';
import 'active_shift_line_options_state.dart';
import 'selected_shift_line_provider.dart';

/// Drives the pre-login active-shift-line picker.
///
/// Behavior:
///   - On first build, kicks off the initial fetch.
///   - `refresh()` re-fetches and (when called from app-resume / pull-to-
///     refresh) re-validates that any previously selected shift-line still
///     appears in the list. If it disappeared, the selection is cleared so
///     bootstrap routes back to the picker / waiting state.
class ActiveShiftLineOptionsController
    extends Notifier<ActiveShiftLineOptionsState> {
  @override
  ActiveShiftLineOptionsState build() {
    Future<void>.microtask(refresh);
    return const ActiveShiftLineOptionsInitial();
  }

  ActiveShiftLineOptionsRepository get _repo =>
      ref.read(activeShiftLineOptionsRepositoryProvider);

  Future<void> refresh() async {
    final List<ActiveShiftLineOption> previous = _previousOptions;
    state = ActiveShiftLineOptionsLoading(previous: previous);

    final ActiveShiftLineOptionsResult result = await _repo.fetch();
    switch (result) {
      case ActiveShiftLineOptionsSuccess(:final options):
        state = ActiveShiftLineOptionsLoaded(options);
        _revalidateSelection(options);
      case ActiveShiftLineOptionsFailure(:final failure):
        state = ActiveShiftLineOptionsFailureState(
          failure: failure,
          previous: previous,
        );
    }
  }

  List<ActiveShiftLineOption> get _previousOptions {
    return switch (state) {
      ActiveShiftLineOptionsLoaded(:final options) => options,
      ActiveShiftLineOptionsLoading(:final previous) => previous,
      ActiveShiftLineOptionsFailureState(:final previous) => previous,
      ActiveShiftLineOptionsInitial() => const <ActiveShiftLineOption>[],
    };
  }

  /// Drops any picker-stage selections whose shift-line no longer appears
  /// in the freshly-fetched list (or has gone non-selectable). Doc §6.3.
  void _revalidateSelection(List<ActiveShiftLineOption> options) {
    final Set<int> selected = ref.read(pickerShiftLineSelectionProvider);
    if (selected.isEmpty) return;
    final Set<int> stillSelectable = options
        .where((o) => o.selectable)
        .map((o) => o.shiftLineId)
        .toSet();
    final Set<int> survivors = selected.intersection(stillSelectable);
    if (survivors.length == selected.length) return;
    ref
        .read(pickerShiftLineSelectionProvider.notifier)
        .replaceWith(survivors);
  }
}

final activeShiftLineOptionsControllerProvider =
    NotifierProvider<
      ActiveShiftLineOptionsController,
      ActiveShiftLineOptionsState
    >(ActiveShiftLineOptionsController.new);
