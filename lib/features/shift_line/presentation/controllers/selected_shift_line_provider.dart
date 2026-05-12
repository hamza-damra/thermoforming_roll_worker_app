import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Picker-stage selection set: the shift-line ids the worker has currently
/// ticked in the multi-select picker. Picker-stage state only — once the
/// PIN flow succeeds, the active sessions live in
/// `multiLineSessionRegistryProvider`.
///
/// Empty at launch and after a successful batch-start. Never persisted to
/// disk.
class PickerShiftLineSelectionNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => <int>{};

  void toggle(int shiftLineId) {
    final Set<int> next = <int>{...state};
    if (!next.add(shiftLineId)) {
      next.remove(shiftLineId);
    }
    state = next;
  }

  void add(int shiftLineId) {
    if (state.contains(shiftLineId)) return;
    state = <int>{...state, shiftLineId};
  }

  void remove(int shiftLineId) {
    if (!state.contains(shiftLineId)) return;
    state = <int>{...state}..remove(shiftLineId);
  }

  void replaceWith(Set<int> ids) {
    state = <int>{...ids};
  }

  void clear() => state = <int>{};
}

final NotifierProvider<PickerShiftLineSelectionNotifier, Set<int>>
pickerShiftLineSelectionProvider =
    NotifierProvider<PickerShiftLineSelectionNotifier, Set<int>>(
      PickerShiftLineSelectionNotifier.new,
    );
