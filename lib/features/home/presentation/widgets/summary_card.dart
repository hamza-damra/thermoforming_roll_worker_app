import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/session_stat_tile.dart';

/// Session summary card.
///
/// V104: the headline is the worker's **consumed kilograms**
/// ([consumedWeightKgInSession]) with rolls-contributed
/// ([rollsContributedInSession]) as the sub-line. On legacy backends that omit
/// the kg field ([consumedWeightKgInSession] == null) it falls back to the
/// completed-rolls count headline.
///
/// [completedRollsByCurrentWorker] is kept on the wire for contract
/// continuity; the "منك: N" sub-line is hidden when it equals
/// [completedRollsInSession]. [isRefreshing] drives a small inline spinner
/// while a background re-fetch is in flight — the card stays visible with the
/// last good data.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.completedRollsInSession,
    required this.completedRollsByCurrentWorker,
    this.consumedWeightKgInSession,
    this.rollsContributedInSession = 0,
    this.isRefreshing = false,
    this.accent,
  });

  final int completedRollsInSession;
  final int completedRollsByCurrentWorker;
  final double? consumedWeightKgInSession;
  final int rollsContributedInSession;
  final bool isRefreshing;
  final Color? accent;

  static const String consumedLabel = 'المستهلك في هذه الجلسة';
  static const String completedLabel = 'الرولات المنجزة في هذه الجلسة';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;

    final IconData icon;
    final String label;
    final String value;
    final String? subline;
    final double? consumed = consumedWeightKgInSession;
    if (consumed != null) {
      // V104 primary metric: consumed kg, with rolls-contributed secondary.
      icon = Icons.scale_rounded;
      label = consumedLabel;
      value = '${consumed.toStringAsFixed(1)} كغ';
      subline = 'ساهمت في: $rollsContributedInSession رولات';
    } else {
      // Legacy fallback: completed-rolls count headline.
      icon = Icons.local_shipping_rounded;
      label = completedLabel;
      value = '$completedRollsInSession';
      final bool showByCurrentWorker =
          completedRollsByCurrentWorker > 0 &&
          completedRollsByCurrentWorker != completedRollsInSession;
      subline = showByCurrentWorker
          ? 'منك: $completedRollsByCurrentWorker'
          : null;
    }

    return AppCard(
      elevated: true,
      accent: color,
      borderRadius: 18,
      child: SessionStatTile(
        icon: icon,
        label: label,
        value: value,
        subline: subline,
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
