import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/session_stat_tile.dart';

/// Session summary card.
///
/// V109: per-worker kilograms can no longer be computed (inter-worker weight
/// boundaries were removed; `consumedWeightKgInSession` / `rollsContributedInSession`
/// now return 0/null for new sessions). We therefore never display a fabricated
/// per-worker kg. Instead the headline is the session-scoped **closed-rolls
/// count** ([completedRollsInSession]) — the number of rolls closed during this
/// roll-worker session (it resets to 0 on each new login to the line). A roll
/// closed via full consumption, partial return, or grinding each counts once.
///
/// This is a session activity count, not a personal-productivity kg metric.
/// [isRefreshing] drives a small inline spinner while a background re-fetch is
/// in flight — the card stays visible with the last good data.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.completedRollsInSession,
    this.isRefreshing = false,
    this.accent,
  });

  final int completedRollsInSession;
  final bool isRefreshing;
  final Color? accent;

  static const String label = 'الرولات التي تم إغلاقها في هذه الجلسة';
  static const String subtitle =
      'تشمل الاستهلاك الكامل، إرجاع المتبقي، والتوصية بالجرش';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;

    return AppCard(
      elevated: true,
      accent: color,
      borderRadius: 18,
      child: SessionStatTile(
        icon: Icons.archive_outlined,
        label: label,
        value: '$completedRollsInSession',
        subline: subtitle,
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
