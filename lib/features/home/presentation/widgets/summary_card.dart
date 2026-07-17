import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/session_stat_tile.dart';

/// Session summary card.
///
/// V123: the roll worker's consumed kilograms are computed again — scoped by
/// operator identity + the current operator shift-line/session ([shiftLineId]),
/// including a live provisional estimate from the currently-mounted roll. The
/// card headlines [consumedWeightKg] ("الوزن المُستهلَك في هذه المناوبة"), then
/// shows the session-scoped closed-rolls count ([completedRollsInSession])
/// directly below it.
///
/// V127 (handoff §6): the cards are intentionally stripped down for factory
/// readability — no decorative icons and no helper sublines. The large numbers
/// carry the meaning.
///
/// Scope note: the kg metric survives a plain logout/login only while the same
/// [shiftLineId] stays active (operator-shift-line scoped, hence "هذه
/// المناوبة"). [completedRollsInSession] is now ALSO operator + shift-line
/// scoped server-side (V127) but keeps the "هذه الجلسة" wording. Both counters
/// come straight from the backend `/summary` — never recomputed locally.
///
/// When [consumedWeightKg] is `null` (a backend that does not compute the
/// metric) the kg tile is hidden — the card never fabricates a kg figure; a
/// genuine `0.0` still shows "0.000 كغ".
///
/// [isRefreshing] drives a small inline spinner while a background re-fetch is
/// in flight — the card stays visible with the last good data.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.completedRollsInSession,
    this.consumedWeightKg,
    this.mountedRollPresent = false,
    this.isRefreshing = false,
    this.accent,
  });

  final int completedRollsInSession;

  /// The worker's consumed kg inside the current operator shift-line/session
  /// (`consumedWeightKgInSession`), including live provisional from the mounted
  /// roll. `null` ⇒ the backend did not compute it ⇒ the kg tile is hidden.
  final double? consumedWeightKg;

  /// `true` when a roll is mounted — the kg may then include a live provisional
  /// estimate, so the provisional hint is shown.
  final bool mountedRollPresent;

  final bool isRefreshing;
  final Color? accent;

  static const String kgLabel = 'الوزن المُستهلَك في هذه المناوبة (كغم)';
  static const String provisionalHint =
      'يشمل الرول المُركّب حالياً ضمن هذه المناوبة كتقدير حتى الإغلاق.';
  static const String label = 'الرولات التي تم إغلاقها في هذه الجلسة';

  static String _kg(double v) => '${v.toStringAsFixed(3)} كغ';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    final double? kg = consumedWeightKg;

    return AppCard(
      elevated: true,
      accent: color,
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (kg != null) ...<Widget>[
            // Primary metric: the worker's kg in this operator shift-line/
            // session (already includes live provisional from the mounted
            // roll). The card total may legitimately exceed the sum of the
            // visible consumed-rolls list — the list is closed rolls only and
            // is capped at 10, while this figure adds the open mounted block —
            // so never assert card == Σ(list).
            SessionStatTile(
              label: kgLabel,
              value: _kg(kg),
              accent: color,
              trailing: isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            if (mountedRollPresent) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                provisionalHint,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const Divider(height: 24),
          ],
          SessionStatTile(
            label: label,
            value: '$completedRollsInSession',
            accent: color,
            // When the kg tile is present it owns the refresh spinner; only
            // fall back to showing it here when the kg tile is hidden.
            trailing: (kg == null && isRefreshing)
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
