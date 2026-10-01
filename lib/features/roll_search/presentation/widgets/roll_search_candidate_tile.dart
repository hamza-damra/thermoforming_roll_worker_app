import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/util/factory_time.dart';
import '../../domain/entities/roll_search_outcome.dart';
import '../roll_search_strings.dart';

/// One of several rolls produced in the same minute. Shows what tells them
/// apart on the label — number, second, type and weight — and whether it can
/// be mounted. Tapping it opens its full preview; nothing is chosen for the
/// worker.
class RollSearchCandidateTile extends StatelessWidget {
  const RollSearchCandidateTile({
    super.key,
    required this.match,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final RollSearchMatch match;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.primary;
    final DateTime? producedAt = match.producedAt;
    final String second = producedAt == null ? '' : _clock(producedAt);
    final double? weight = match.currentWeightKg ?? match.producedWeightKg;
    return Material(
      color: selected ? tint.withValues(alpha: 0.08) : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('rollSearchCandidate.${match.generatedRollId}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? tint : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                match.mountable
                    ? Icons.check_circle_rounded
                    : Icons.block_rounded,
                color: match.mountable ? AppColors.success : AppColors.error,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      match.generatedRollId,
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        match.rollTypeDisplayName ??
                            match.rollTypeRollCode ??
                            '',
                        if (weight != null) RollSearchStrings.kg(weight),
                        match.consumptionStateLabel ?? match.consumptionState,
                      ].where((String s) => s.isNotEmpty).join(' • '),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (second.isNotEmpty)
                Text(
                  second,
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.label,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// `hh:mm:ss` in factory time — the seconds are what differ between rolls
  /// produced in the same minute.
  static String _clock(DateTime instant) {
    final DateTime t = toFactoryTime(instant);
    final int hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(hour12)}:${two(t.minute)}:${two(t.second)}';
  }
}
