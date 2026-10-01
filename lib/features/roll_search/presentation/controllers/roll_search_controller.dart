import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure_classification.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../data/roll_search_providers.dart';
import '../../domain/entities/production_time_input.dart';
import '../../domain/entities/roll_search_outcome.dart';
import '../../domain/roll_search_repository.dart';
import 'roll_search_state.dart';

/// Drives «بحث بوقت الإنتاج» for one shift-line. Search only — the mount from
/// the preview goes through `rollScanControllerProvider`, the same path as a
/// scanned or typed roll number.
class RollSearchController extends FamilyNotifier<RollSearchState, int> {
  late int _shiftLineId;

  @override
  RollSearchState build(int arg) {
    _shiftLineId = arg;
    return const RollSearchIdle();
  }

  RollSearchRepository get _repo => ref.read(rollSearchRepositoryProvider);

  /// Searches [query]. Ignored while a search is already in flight.
  ///
  /// With [keepSelection], a roll the worker had chosen stays selected when
  /// it is still among the matches (used by [refresh]).
  Future<void> search(
    ProductionTimeQuery query, {
    bool keepSelection = false,
  }) async {
    final RollSearchState current = state;
    if (current is RollSearchLoading) return;
    final RollSearchLoaded? previous = current is RollSearchLoaded
        ? current
        : null;
    state = RollSearchLoading(query, previous: previous);

    final RollSearchResult result = await _repo.searchByProductionTime(
      shiftLineId: _shiftLineId,
      query: query,
    );
    switch (result) {
      case RollSearchSuccess(:final RollSearchOutcome outcome):
        state = RollSearchLoaded(
          query: query,
          outcome: outcome,
          selectedRollNumber: _initialSelection(
            outcome,
            keepSelection ? previous?.selectedRollNumber : null,
          ),
        );
      case RollSearchFailure(:final failure):
        state = RollSearchFailed(query: query, failure: failure);
        // Same rule as the scan: only a session/line fault sends the worker
        // back to the PIN overlay.
        if (isSessionLossCascade(failure)) {
          await ref
              .read(multiLineSessionRegistryProvider.notifier)
              .notifySessionLost(_shiftLineId);
        }
    }
  }

  /// Re-runs the last search, keeping the chosen roll, so the preview shows
  /// the line as it is now — e.g. after a mount was refused.
  Future<void> refresh() async {
    final RollSearchState current = state;
    final ProductionTimeQuery? query = switch (current) {
      RollSearchLoaded(:final query) => query,
      RollSearchFailed(:final query) => query,
      _ => null,
    };
    if (query == null) return;
    await search(query, keepSelection: true);
  }

  /// Chooses which of several matches to preview. The backend never picks
  /// one; only the worker does, by comparing the label.
  void select(String generatedRollId) {
    final RollSearchState current = state;
    if (current is! RollSearchLoaded) return;
    state = current.select(generatedRollId);
  }

  void reset() {
    state = const RollSearchIdle();
  }

  static String? _initialSelection(RollSearchOutcome outcome, String? keep) {
    if (outcome.status == RollSearchStatus.found) {
      return outcome.matches.single.generatedRollId;
    }
    if (keep != null &&
        outcome.matches.any((RollSearchMatch m) => m.generatedRollId == keep)) {
      return keep;
    }
    return null;
  }
}

final rollSearchControllerProvider =
    NotifierProvider.family<RollSearchController, RollSearchState, int>(
      RollSearchController.new,
    );
