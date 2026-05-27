import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

/// Summary card showing the session-scoped completed-roll count.
///
/// [completedRollsByCurrentWorker] is kept on the wire for contract
/// continuity, but it equals [completedRollsInSession] now that the counter
/// is session-scoped. The "منك: N" sub-line is hidden when the two are equal
/// to avoid a visually duplicated number.
/// [isRefreshing] drives a small inline spinner while a background re-fetch
/// is in flight — the card stays visible with the last good data.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.completedRollsInSession,
    required this.completedRollsByCurrentWorker,
    this.isRefreshing = false,
  });

  final int completedRollsInSession;
  final int completedRollsByCurrentWorker;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final bool showByCurrentWorker =
        completedRollsByCurrentWorker > 0 &&
        completedRollsByCurrentWorker != completedRollsInSession;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الرولات المنجزة في هذه الجلسة',
                    style: AppTextStyles.metricLabel),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$completedRollsInSession',
                      style: AppTextStyles.metricValue,
                    ),
                    if (showByCurrentWorker) ...[
                      const SizedBox(width: 10),
                      Text(
                        'منك: $completedRollsByCurrentWorker',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isRefreshing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
