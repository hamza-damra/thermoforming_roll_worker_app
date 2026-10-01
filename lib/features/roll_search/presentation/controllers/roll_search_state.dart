import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/production_time_input.dart';
import '../../domain/entities/roll_search_outcome.dart';

/// Production-time search state for one shift-line. Sealed so the screen
/// handles every branch.
@immutable
sealed class RollSearchState {
  const RollSearchState();
}

/// Nothing searched yet.
class RollSearchIdle extends RollSearchState {
  const RollSearchIdle();
}

/// A search is in flight; further searches are ignored until it ends.
class RollSearchLoading extends RollSearchState {
  const RollSearchLoading(this.query, {this.previous});

  final ProductionTimeQuery query;

  /// The result being refreshed, kept on screen while the refresh runs.
  final RollSearchLoaded? previous;
}

/// The backend answered. [selectedRollNumber] is the roll being previewed:
/// set automatically for a single match, chosen by the worker among several.
class RollSearchLoaded extends RollSearchState {
  const RollSearchLoaded({
    required this.query,
    required this.outcome,
    this.selectedRollNumber,
  });

  final ProductionTimeQuery query;
  final RollSearchOutcome outcome;
  final String? selectedRollNumber;

  RollSearchMatch? get selected {
    for (final RollSearchMatch m in outcome.matches) {
      if (m.generatedRollId == selectedRollNumber) return m;
    }
    return null;
  }

  RollSearchLoaded select(String? generatedRollId) => RollSearchLoaded(
    query: query,
    outcome: outcome,
    selectedRollNumber: generatedRollId,
  );
}

/// The search call failed (invalid time, session, network, …).
class RollSearchFailed extends RollSearchState {
  const RollSearchFailed({required this.query, required this.failure});

  final ProductionTimeQuery query;
  final AppFailure failure;
}
