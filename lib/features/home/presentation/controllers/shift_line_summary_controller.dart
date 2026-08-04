import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/diagnostics/refresh_log.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_classification.dart';
import '../../../operator_dashboard_sse/domain/entities/operator_dashboard_event.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../data/shift_line_summary_providers.dart';
import '../../domain/entities/shift_line_summary.dart';
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

  /// Whether the most recent fetch failed. Stays `true` even when prior data
  /// is kept visible (a background/pull refresh that could not reach the
  /// backend keeps the last good [SummaryLoaded]), so pull-to-refresh can
  /// surface a failure snackbar without the controller having to throw.
  bool _lastRefreshFailed = false;
  bool get lastRefreshFailed => _lastRefreshFailed;

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

  ShiftLineSummary _mergeRestWithSseOverlays(ShiftLineSummary fresh) {
    final ShiftLineSummaryState current = state;
    if (current is! SummaryLoaded) return fresh;
    final ShiftLineSummary prev = current.summary;
    return fresh.copyWith(
      activeProduct: fresh.activeProduct ?? prev.activeProduct,
      returnedRemainingRoll:
          fresh.returnedRemainingRoll ?? prev.returnedRemainingRoll,
    );
  }

  Future<void> _doFetch() async {
    final SummaryResult result = await _repo.fetchSummary(
      shiftLineId: _shiftLineId,
    );
    switch (result) {
      case SummarySuccess(:final summary):
        _lastRefreshFailed = false;
        state = SummaryLoaded(
          _mergeRestWithSseOverlays(summary),
          isRefreshing: false,
        );
        refreshLog(
          'summary refreshed (shiftLine=$_shiftLineId): '
          'activeOperator=${summary.activeOperatorName}, '
          'product=${summary.activeProduct?.name}, '
          'blocked=${summary.blocked}, '
          'lifecycle=${summary.lineLifecycleStatus}',
        );
      case SummaryFailure(:final failure):
        refreshLog(
          'summary refresh failed (shiftLine=$_shiftLineId): $failure',
        );
        await _onFailure(failure);
    }
  }

  Future<void> _onFailure(AppFailure failure) async {
    _lastRefreshFailed = true;
    final ShiftLineSummaryState current = state;
    if (current is SummaryLoaded) {
      // Drop the refreshing flag; keep showing last good data.
      state = current.copyWith(isRefreshing: false);
    } else {
      state = SummaryError(failure);
    }
    // A device-key fault is excluded by `isSessionLossCascade` — it leaves the
    // session valid, so it must not funnel the worker back to the PIN overlay.
    if (isSessionLossCascade(failure)) {
      await ref
          .read(multiLineSessionRegistryProvider.notifier)
          .notifySessionLost(_shiftLineId);
    }
  }

  SummaryLoaded? _loadedOrNull() {
    final ShiftLineSummaryState s = state;
    return s is SummaryLoaded ? s : null;
  }

  void _setSummary(ShiftLineSummary summary) {
    final bool refreshing = _loadedOrNull()?.isRefreshing ?? false;
    state = SummaryLoaded(summary, isRefreshing: refreshing);
  }

  void applyProductChanged(ProductChangedPayload payload) {
    final SummaryLoaded? cur = _loadedOrNull();
    if (cur == null) return;
    _setSummary(
      cur.summary.copyWith(
        activeProduct: SummaryActiveProduct(
          productId: payload.newProductId,
          name: payload.newProductName,
        ),
      ),
    );
  }

  void applyRollSegmentRecorded(RollConsumptionSegmentRecordedPayload payload) {
    final SummaryLoaded? cur = _loadedOrNull();
    if (cur == null) return;
    final SummaryMountedRoll? mount = cur.summary.mountedRoll;
    if (mount == null || mount.rollId != payload.rollId) return;
    _setSummary(
      cur.summary.copyWith(
        mountedRoll: mount.copyWith(lastKnownWeightKg: payload.currentWeight),
      ),
    );
  }

  /// Returns `false` when the event references a roll the UI has never loaded.
  bool applyRollContinued(RollContinuedWithNewProductPayload payload) {
    final SummaryLoaded? cur = _loadedOrNull();
    if (cur == null) return false;
    final SummaryMountedRoll? mount = cur.summary.mountedRoll;
    if (mount == null || mount.rollId != payload.rollId) return false;
    _setSummary(
      cur.summary.copyWith(
        mountedRoll: mount.copyWith(lastKnownWeightKg: payload.currentWeight),
        activeProduct: SummaryActiveProduct(
          productId: payload.newProductId,
          name: payload.newProductName,
        ),
      ),
    );
    return true;
  }

  void applyRollReturnedRemaining(RollReturnedRemainingPayload payload) {
    final SummaryLoaded? cur = _loadedOrNull();
    if (cur == null) return;
    final SummaryActiveProduct? nextProduct =
        payload.newProductId != null && payload.newProductName != null
        ? SummaryActiveProduct(
            productId: payload.newProductId!,
            name: payload.newProductName!,
          )
        : cur.summary.activeProduct;
    _setSummary(
      cur.summary.copyWith(
        clearMountedRoll: true,
        activeProduct: nextProduct,
        returnedRemainingRoll: ReturnedRemainingRoll(
          generatedRollId: payload.rollNumber,
          returnedWeightKg: payload.returnedWeight,
          canPrintLabel: payload.canPrintLabel,
          oldProductName: payload.oldProductName,
          newProductName: payload.newProductName,
        ),
      ),
    );
  }

  void acknowledgeReturnedRemaining() {
    final SummaryLoaded? cur = _loadedOrNull();
    if (cur == null) return;
    _setSummary(cur.summary.copyWith(clearReturnedRemainingRoll: true));
  }

  /// Returns `false` when the snapshot references an unknown mount.
  bool applyMachineRollState(MachineRollStateUpdatedPayload payload) {
    final SummaryLoaded? cur = _loadedOrNull();
    if (cur == null) return false;
    final ShiftLineSummary s = cur.summary;

    final SummaryActiveProduct? nextActive =
        payload.activeProductId != null && payload.activeProductName != null
        ? SummaryActiveProduct(
            productId: payload.activeProductId!,
            name: payload.activeProductName!,
          )
        : s.activeProduct;

    if (payload.hasNoMount) {
      _setSummary(
        s.copyWith(clearMountedRoll: true, activeProduct: nextActive),
      );
      return true;
    }

    final int? mid = payload.mountedRollId;
    final SummaryMountedRoll? mount = s.mountedRoll;
    if (mid != null &&
        mount != null &&
        mount.rollId == mid &&
        payload.mountedRollCurrentWeight != null) {
      _setSummary(
        s.copyWith(
          mountedRoll: mount.copyWith(
            lastKnownWeightKg: payload.mountedRollCurrentWeight,
          ),
          activeProduct: nextActive,
        ),
      );
      return true;
    }

    if (mid != null && (mount == null || mount.rollId != mid)) {
      return false;
    }

    return false;
  }
}

final shiftLineSummaryControllerProvider =
    NotifierProvider.family<
      ShiftLineSummaryController,
      ShiftLineSummaryState,
      int
    >(ShiftLineSummaryController.new);
