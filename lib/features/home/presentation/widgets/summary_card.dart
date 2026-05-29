import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/session_stat_tile.dart';

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
    this.accent,
  });

  final int completedRollsInSession;
  final int completedRollsByCurrentWorker;
  final bool isRefreshing;
  final Color? accent;

  static const String label = 'الرولات المنجزة في هذه الجلسة';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    final bool showByCurrentWorker =
        completedRollsByCurrentWorker > 0 &&
        completedRollsByCurrentWorker != completedRollsInSession;
    return AppCard(
      elevated: true,
      accent: color,
      borderRadius: 18,
      child: SessionStatTile(
        icon: Icons.local_shipping_rounded,
        label: label,
        value: '$completedRollsInSession',
        subline: showByCurrentWorker ? 'منك: $completedRollsByCurrentWorker' : null,
        accent: color,
        trailing: isRefreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }
}
