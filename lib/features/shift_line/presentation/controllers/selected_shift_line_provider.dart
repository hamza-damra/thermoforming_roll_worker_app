import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shift-line the device is currently working against, or `null` when
/// no line is selected.
///
/// **Stage-3 behavior**: this is `null` in production builds because the
/// backend has not yet shipped the active-shift-lines picker endpoint
/// (requirements §7 / §24 gap #1). The waiting screen handles the null
/// case. Tests override this provider to inject a fake shift-line id.
///
/// **Stage 4** will replace the always-null behavior with backend
/// discovery once the picker endpoint exists.
class SelectedShiftLineNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  /// Called from the (future) shift-line picker once a line is chosen.
  void select(int shiftLineId) => state = shiftLineId;

  /// Cleared on cascade-on-end / shift-line ended elsewhere.
  void clear() => state = null;
}

final selectedShiftLineIdProvider =
    NotifierProvider<SelectedShiftLineNotifier, int?>(
      SelectedShiftLineNotifier.new,
    );
