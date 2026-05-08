import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The shift-line the device is currently working against, or `null` when
/// no line is selected.
///
/// ### Production behavior
///
/// In production builds this provider stays `null` for as long as the
/// backend has not shipped the active-shift-lines picker endpoint
/// (requirements §7 / §24 gap #1 — `GET /shift-lines/active-options`).
/// `WaitingForLineScreen` handles the `null` case as a safe blocked state.
///
/// There is intentionally **no** alternative path from `null` to a real
/// shift-line in this stage: no manual entry, no build-time bypass flag,
/// no hardcoded value, no debug long-press. The blocked state is the
/// production-correct behavior until backend support exists.
///
/// ### Cascade-on-end
///
/// `BootstrapScreen` calls [SelectedShiftLineNotifier.clear] when the auth
/// state transitions to `RollWorkerAuthLineGone`, dropping the worker back
/// to the waiting screen. The same notifier method will be used by the
/// (future) shift-line picker controller when the operator ends the line
/// from another device.
///
/// ### Tests
///
/// Test scenarios that need a non-null shift-line should override this
/// provider with a fixed id, e.g.
/// `selectedShiftLineIdProvider.overrideWith(() => StaticNotifier(800))`.
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
