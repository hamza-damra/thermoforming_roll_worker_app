import 'package:flutter/material.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_shimmer_skeleton.dart';

/// First-load skeleton for the per-line home page.
///
/// Rendered only when the per-line `ShiftLineSummaryController` is in
/// [SummaryLoading] state with no previous data — i.e., a genuine cold
/// fetch. Background refreshes keep the previous data visible (no
/// shimmer) so the resume path never collapses to placeholders.
class HomeShimmerSkeleton extends StatelessWidget {
  const HomeShimmerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmerSkeleton.wrap(
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Active product chip placeholder.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppShimmerBlock(width: 220, height: 44, borderRadius: 14),
          ),
          SizedBox(height: 12),
          // Summary card placeholder.
          AppCard(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AppShimmerLine(width: 140, height: 12),
                      SizedBox(height: 10),
                      AppShimmerLine(width: 80, height: 22),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // Section heading placeholder.
          Padding(
            padding: EdgeInsetsDirectional.only(start: 4, bottom: 8),
            child: AppShimmerLine(width: 200, height: 14),
          ),
          // Three consumed-roll card placeholders.
          _SkeletonConsumedRollCard(),
          SizedBox(height: 8),
          _SkeletonConsumedRollCard(),
          SizedBox(height: 8),
          _SkeletonConsumedRollCard(),
        ],
      ),
    );
  }
}

class _SkeletonConsumedRollCard extends StatelessWidget {
  const _SkeletonConsumedRollCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Row(
        children: <Widget>[
          AppShimmerBlock(width: 32, height: 32, borderRadius: 16),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppShimmerLine(width: 180, height: 14),
                SizedBox(height: 6),
                AppShimmerLine(width: 90, height: 12),
              ],
            ),
          ),
          SizedBox(width: 8),
          AppShimmerLine(width: 60, height: 12),
        ],
      ),
    );
  }
}
