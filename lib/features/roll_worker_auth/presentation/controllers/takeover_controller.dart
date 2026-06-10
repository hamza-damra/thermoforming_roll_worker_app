import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/dto/roll_worker_takeover_request.dart';
import '../../data/roll_worker_auth_providers.dart';
import '../../domain/entities/roll_worker_takeover.dart';
import '../../domain/session_batch_repository.dart';
import '../../domain/takeover_repository.dart';
import 'multi_line_session_registry.dart';
import 'takeover_state.dart';

/// Drives the takeover screen for one shift-line.
///
/// On a successful `takeover-with-roll-declaration` the line is resolved and
/// claimed for the incoming worker server-side; we then seed the local session
/// via a **uniform re-login** (`startBatch({shiftLineId})` →
/// [MultiLineSessionRegistry.onBatchSuccess]). Re-login is a clean same-worker
/// replace (it never re-triggers takeover, which only fires for a *different*
/// worker) and also covers the `alreadyProcessed: true` recovery — so a fresh
/// success and a duplicate both route through the same path.
///
/// A single `clientRequestId` is generated on the first submit, reused on every
/// retry, and cleared on success / [cancel] (idempotency, handoff §6/§11).
class TakeoverController extends FamilyNotifier<TakeoverState, int> {
  late int _shiftLineId;
  String? _clientRequestId;

  @override
  TakeoverState build(int arg) {
    _shiftLineId = arg;
    return const TakeoverIdle();
  }

  TakeoverRepository get _takeoverRepo =>
      ref.read(takeoverRepositoryProvider);

  SessionBatchRepository get _batchRepo =>
      ref.read(sessionBatchRepositoryProvider);

  /// The current attempt's idempotency key — exposed for tests.
  String? get clientRequestId => _clientRequestId;

  /// Submits the takeover with the incoming worker's [pin]. [currentWeightKg]
  /// is required for [RollWorkerTakeoverAction.rollRemainsMounted] and ignored
  /// for [RollWorkerTakeoverAction.fullConsumptionAndClose].
  Future<void> submit({
    required RollWorkerTakeoverAction action,
    required String pin,
    double? currentWeightKg,
  }) async {
    if (state is TakeoverSubmitting) return; // double-submit guard
    state = const TakeoverSubmitting();

    // Generate once, reuse on every retry until success / cancel.
    _clientRequestId ??= const Uuid().v4();

    final RollWorkerTakeoverRequest request = RollWorkerTakeoverRequest(
      shiftLineId: _shiftLineId,
      incomingOperatorPin: pin,
      action: action,
      currentWeightKg: currentWeightKg,
      clientRequestId: _clientRequestId!,
    );

    final TakeoverResult result = await _takeoverRepo.takeover(request);
    switch (result) {
      case TakeoverSuccess():
        await _seedSessionViaReLogin(pin);
      case TakeoverFailure(:final failure):
        // Keep the clientRequestId so a retry is idempotent.
        state = TakeoverFailureState(failure);
    }
  }

  /// Re-runs the single-line batch to mint a fresh session for the now-owned
  /// line and seed the registry. Covers both the fresh-success and
  /// `alreadyProcessed` recoveries.
  Future<void> _seedSessionViaReLogin(String pin) async {
    final BatchAuthResult batchResult = await _batchRepo.startBatch(
      pin: pin,
      shiftLineIds: <int>{_shiftLineId},
    );
    switch (batchResult) {
      case BatchAuthSuccessResult(:final outcome):
        await ref
            .read(multiLineSessionRegistryProvider.notifier)
            .onBatchSuccess(outcome.sessions);
        // The tab flips to authorized and removes the takeover card; clear the
        // idempotency key and settle back to idle.
        _clientRequestId = null;
        state = const TakeoverIdle();
      case BatchAuthFailureResult(:final failure):
        // The takeover succeeded but seeding the session failed — keep the
        // clientRequestId so a retry stays idempotent and surface the error.
        state = TakeoverFailureState(failure);
    }
  }

  /// Worker cancelled the takeover screen. Discards the idempotency key and
  /// resets so the next attempt starts a fresh one.
  void cancel() {
    _clientRequestId = null;
    state = const TakeoverIdle();
  }
}

final takeoverControllerProvider =
    NotifierProvider.family<TakeoverController, TakeoverState, int>(
      TakeoverController.new,
    );
