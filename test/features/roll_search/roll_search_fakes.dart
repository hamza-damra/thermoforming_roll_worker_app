import 'dart:async';

import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/entities/mounted_roll.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/entities/production_time_input.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/entities/roll_search_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/roll_search_repository.dart';

const int kSearchShiftLineId = 800;

const ProductionTimeQuery kSearchQuery = ProductionTimeQuery(
  year: 2026,
  month: 9,
  day: 30,
  hour24: 14,
  minute: 5,
);

/// One found roll; mountable unless [refusal] is given.
RollSearchMatch searchMatch({
  int rollId = 11,
  String generatedRollId = '777000000011',
  bool mountable = true,
  BusinessFailure? refusal,
  double producedWeightKg = 250.5,
  double? currentWeightKg,
  String stateLabel = 'متاح',
  DateTime? producedAt,
}) => RollSearchMatch(
  rollId: rollId,
  generatedRollId: generatedRollId,
  producedAt: producedAt ?? DateTime.utc(2026, 9, 30, 11, 5, 37),
  rollTypeRollCode: 'TT-1S B250 White',
  rollTypeDisplayName: 'TT-1S B250',
  colorName: 'White',
  productionKind: 'NORMAL',
  producedWeightKg: producedWeightKg,
  currentWeightKg: currentWeightKg ?? producedWeightKg,
  consumptionState: 'AVAILABLE',
  consumptionStateLabel: stateLabel,
  mountable: mountable,
  mountRefusal: mountable
      ? null
      : (refusal ?? const BusinessFailure(code: ErrorCode.unknown)),
);

RollSearchOutcome foundOutcome(RollSearchMatch m) => RollSearchOutcome(
  status: RollSearchStatus.found,
  matchCount: 1,
  matches: <RollSearchMatch>[m],
  searchedLocalMinute: '2026-09-30T14:05',
);

RollSearchOutcome notFoundOutcome() => const RollSearchOutcome(
  status: RollSearchStatus.notFound,
  matchCount: 0,
  matches: <RollSearchMatch>[],
  searchedLocalMinute: '2026-09-30T14:05',
);

RollSearchOutcome multipleOutcome(
  List<RollSearchMatch> matches, {
  int? matchCount,
}) => RollSearchOutcome(
  status: RollSearchStatus.multipleMatches,
  matchCount: matchCount ?? matches.length,
  matches: matches,
  searchedLocalMinute: '2026-09-30T14:05',
);

/// Answers searches from a queue (the last answer repeats), optionally gated
/// on a [Completer] so a test can hold a search in flight.
class FakeRollSearchRepository implements RollSearchRepository {
  FakeRollSearchRepository(List<RollSearchResult> answers)
    : _answers = List<RollSearchResult>.of(answers);

  final List<RollSearchResult> _answers;
  final List<ProductionTimeQuery> queries = <ProductionTimeQuery>[];
  Completer<void>? gate;

  int get calls => queries.length;

  @override
  Future<RollSearchResult> searchByProductionTime({
    required int shiftLineId,
    required ProductionTimeQuery query,
  }) async {
    queries.add(query);
    final Completer<void>? g = gate;
    if (g != null) await g.future;
    return _answers.length > 1 ? _answers.removeAt(0) : _answers.first;
  }
}

/// Scan repository recording mounts; answers from a queue (last repeats).
class FakeRollScanRepository implements RollScanRepository {
  FakeRollScanRepository(List<RollScanResult> answers)
    : _answers = List<RollScanResult>.of(answers);

  final List<RollScanResult> _answers;
  final List<({int shiftLineId, String generatedRollId})> mounts =
      <({int shiftLineId, String generatedRollId})>[];

  @override
  Future<RollScanResult> mountRoll({
    required int shiftLineId,
    required String generatedRollId,
  }) async {
    mounts.add((shiftLineId: shiftLineId, generatedRollId: generatedRollId));
    return _answers.length > 1 ? _answers.removeAt(0) : _answers.first;
  }
}

MountedRoll mountedRollFor(String generatedRollId) => MountedRoll(
  rollId: 1,
  generatedRollId: generatedRollId,
  rollTypeId: 70,
  rollTypeRollCode: 'TT-1S B250 White',
  rollTypeDisplayName: 'TT-1S B250',
  colorName: 'White',
  productTypeId: 5,
  productTypeName: 'أحمر',
  consumptionItemId: 5000,
  activeSegmentId: 6000,
  state: 'IN_CONSUMPTION',
  lastKnownWeightKg: 250.5,
);
