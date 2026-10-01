import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/errors/failure_classification.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/util/factory_time.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/loading_button.dart';
import '../../../roll_scan/domain/entities/roll_scan_warning.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_controller.dart';
import '../../../roll_scan/presentation/controllers/roll_scan_state.dart';
import '../../../roll_scan/presentation/screens/scan_roll_screen.dart';
import '../../../roll_scan/presentation/widgets/curing_max_warning_dialog.dart';
import '../../../roll_scan/presentation/widgets/curing_min_violation_dialog.dart';
import '../../../roll_scan/presentation/widgets/roll_scan_blocked_dialog.dart';
import '../../domain/entities/production_time_input.dart';
import '../../domain/entities/roll_search_outcome.dart';
import '../controllers/roll_search_controller.dart';
import '../controllers/roll_search_state.dart';
import '../roll_search_strings.dart';
import '../widgets/production_time_form.dart';
import '../widgets/roll_search_candidate_tile.dart';
import '../widgets/roll_search_match_card.dart';

/// «بحث بوقت الإنتاج»: find a roll whose barcode cannot be scanned by the
/// production minute printed on its label, preview it, and mount it.
///
/// The search is read-only. تركيب الرول calls the same
/// `rollScanControllerProvider.mountRoll` as a scanned or typed roll number,
/// so the backend applies every mount rule, lock and check again, and the
/// outcome is handled with the scan's own dialogs.
class ProductionTimeSearchScreen extends ConsumerStatefulWidget {
  const ProductionTimeSearchScreen({
    super.key,
    required this.shiftLineId,
    this.accentColor,
    this.now,
  });

  final int shiftLineId;
  final Color? accentColor;

  /// Current instant, injectable for tests; the year and month are prefilled
  /// from it in factory time.
  final DateTime? now;

  @override
  ConsumerState<ProductionTimeSearchScreen> createState() =>
      _ProductionTimeSearchScreenState();
}

class _ProductionTimeSearchScreenState
    extends ConsumerState<ProductionTimeSearchScreen> {
  /// Roll number of the mount this screen started, until its outcome is
  /// handled. Scan-controller changes with no mount of ours pending are
  /// ignored.
  String? _mountingRollNumber;

  /// Why the last mount from this screen was refused, when no dialog shows it.
  AppFailure? _mountFailure;

  int get _shiftLineId => widget.shiftLineId;

  RollScanController get _scan =>
      ref.read(rollScanControllerProvider(_shiftLineId).notifier);

  RollSearchController get _search =>
      ref.read(rollSearchControllerProvider(_shiftLineId).notifier);

  void _onSearch(ProductionTimeQuery query) {
    setState(() => _mountFailure = null);
    _search.search(query);
  }

  void _mount(RollSearchMatch match) {
    setState(() {
      _mountFailure = null;
      _mountingRollNumber = match.generatedRollId;
    });
    _scan.mountRoll(match.generatedRollId);
  }

  Future<void> _onMounted(RollScanMounted next) async {
    _mountingRollNumber = null;
    RollScanWarning? maxWarning;
    for (final RollScanWarning w in next.warnings) {
      if (w.code == ScanRollScreen.curingMaxWarningCode) {
        maxWarning = w;
        break;
      }
    }
    if (maxWarning != null) {
      await showCuringMaxWarningDialog(
        context,
        warning: maxWarning,
        accent: widget.accentColor,
      );
      if (!mounted) return;
    } else {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(RollSearchStrings.mounted)),
        );
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _onMountFailed(RollScanFailureState next) async {
    final String? rollNumber = _mountingRollNumber;
    _mountingRollNumber = null;
    final AppFailure failure = next.failure;
    // The refusal is shown here; leave nothing behind for the scan screen.
    _scan.clearError();

    if (!isSessionLossCascade(failure)) {
      // The line or the roll changed since the preview; show it as it is now.
      _search.refresh();
    }
    if (failure is BusinessFailure) {
      if (failure.code == ErrorCode.rollCuringMinimumNotMet) {
        await showCuringMinViolationDialog(
          context,
          failure: failure,
          accent: widget.accentColor,
          rollNumber: rollNumber,
        );
        return;
      }
      final RollScanBlockedKind? kind = rollScanBlockedKindFor(failure.code);
      if (kind != null) {
        await showRollScanBlockedDialog(
          context,
          kind: kind,
          failure: failure,
          accent: widget.accentColor,
        );
        return;
      }
    }
    if (mounted) setState(() => _mountFailure = failure);
  }

  /// The scan's dialog for a refusal shown in the preview, when it has one.
  VoidCallback? _refusalDetails(RollSearchMatch match) {
    final BusinessFailure? refusal = match.mountRefusal;
    if (refusal == null) return null;
    if (refusal.code == ErrorCode.rollCuringMinimumNotMet) {
      return () => showCuringMinViolationDialog(
        context,
        failure: refusal,
        accent: widget.accentColor,
        rollNumber: match.generatedRollId,
      );
    }
    final RollScanBlockedKind? kind = rollScanBlockedKindFor(refusal.code);
    if (kind == null) return null;
    return () => showRollScanBlockedDialog(
      context,
      kind: kind,
      failure: refusal,
      accent: widget.accentColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final RollSearchState searchState = ref.watch(
      rollSearchControllerProvider(_shiftLineId),
    );
    final RollScanState scanState = ref.watch(
      rollScanControllerProvider(_shiftLineId),
    );

    ref.listen<RollScanState>(rollScanControllerProvider(_shiftLineId), (
      RollScanState? prev,
      RollScanState next,
    ) {
      if (_mountingRollNumber == null) return;
      if (next is RollScanMounted && prev is! RollScanMounted) {
        _onMounted(next);
      } else if (next is RollScanFailureState) {
        _onMountFailed(next);
      }
    });

    final DateTime today = toFactoryTime(widget.now ?? DateTime.now());
    final Color accent = widget.accentColor ?? AppColors.primary;
    final bool isMounting =
        _mountingRollNumber != null && scanState is RollScanSubmitting;

    return Scaffold(
      appBar: AppBar(
        title: const Text(RollSearchStrings.title),
        backgroundColor: accent,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            ProductionTimeForm(
              initialYear: today.year,
              initialMonth: today.month,
              isSearching: searchState is RollSearchLoading,
              accent: accent,
              onSearch: _onSearch,
            ),
            const SizedBox(height: 16),
            ..._results(searchState, accent: accent, isMounting: isMounting),
            if (_mountFailure != null) ...<Widget>[
              const SizedBox(height: 12),
              InlineError(message: arabicMessageFor(_mountFailure!)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _results(
    RollSearchState state, {
    required Color accent,
    required bool isMounting,
  }) {
    switch (state) {
      case RollSearchIdle():
        return const <Widget>[];
      case RollSearchLoading(:final RollSearchLoaded? previous):
        // A refresh keeps the result on screen under a thin progress bar.
        if (previous == null) return const <Widget>[CenteredLoader()];
        return <Widget>[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          ..._results(previous, accent: accent, isMounting: false),
        ];
      case RollSearchFailed(:final AppFailure failure):
        return <Widget>[InlineError(message: arabicMessageFor(failure))];
      case RollSearchLoaded(:final RollSearchOutcome outcome):
        final RollSearchMatch? selected = state.selected;
        Widget card(RollSearchMatch m) => RollSearchMatchCard(
          match: m,
          accent: accent,
          isMounting: isMounting,
          onMount: () => _mount(m),
          onShowRefusalDetails: _refusalDetails(m),
        );
        return switch (outcome.status) {
          RollSearchStatus.notFound => const <Widget>[_NotFoundCard()],
          RollSearchStatus.found => <Widget>[card(outcome.matches.single)],
          RollSearchStatus.multipleMatches => <Widget>[
            Text(
              RollSearchStrings.multipleFound(outcome.matchCount),
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (outcome.isTruncated)
              Text(
                RollSearchStrings.truncated(outcome.matches.length),
                style: AppTextStyles.caption,
              ),
            const SizedBox(height: 8),
            for (final RollSearchMatch m in outcome.matches) ...<Widget>[
              RollSearchCandidateTile(
                match: m,
                accent: accent,
                selected: m.generatedRollId == state.selectedRollNumber,
                onTap: () => _search.select(m.generatedRollId),
              ),
              const SizedBox(height: 8),
            ],
            if (selected != null) ...<Widget>[
              const SizedBox(height: 8),
              card(selected),
            ],
          ],
        };
    }
  }
}

class _NotFoundCard extends StatelessWidget {
  const _NotFoundCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 28,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(RollSearchStrings.notFound, style: AppTextStyles.h3),
                SizedBox(height: 4),
                Text(
                  RollSearchStrings.notFoundHint,
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
