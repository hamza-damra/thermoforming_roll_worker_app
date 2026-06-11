import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../domain/entities/shift_line_summary.dart';

/// Current mounted-roll card driven by [SummaryMountedRoll].
///
/// Shows the 12-digit roll number, an "in consumption" status pill, and the
/// backend-authoritative latest known weight of the mounted roll
/// (`آخر وزن معروف`). The weight is read-only — never editable here — and is
/// taken straight from [SummaryMountedRoll.lastKnownWeightKg]; the app never
/// invents or derives it. When the backend has not recorded a weight yet
/// (`null`), the card shows `الوزن غير متوفر` and still renders the roll id.
/// Rendered only when the backend returns a non-null `mountedRoll` in the
/// summary response (the no-mount state uses `EmptyRollStateCard`).
class CompactMountedRollCard extends StatelessWidget {
  const CompactMountedRollCard({
    super.key,
    required this.roll,
    this.accentColor,
  });

  final SummaryMountedRoll roll;
  final Color? accentColor;

  static const String _heading = 'الرول المركب حالياً';
  static const String _rollNumberLabel = 'رقم الرول';
  static const String _statusText = 'قيد الاستهلاك';

  /// Operationally accurate wording: the value is the *latest known* persisted
  /// weight for the mounted roll, not necessarily a live reading.
  static const String _weightLabel = 'آخر وزن معروف';
  static const String _weightUnavailable = 'الوزن غير متوفر';

  @override
  Widget build(BuildContext context) {
    final Color accent = accentColor ?? AppColors.primary;
    final double? weightKg = roll.lastKnownWeightKg;

    return AppCard(
      elevated: true,
      accent: accent,
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: _heading,
            icon: Icons.qr_code_2_rounded,
            accent: accent,
            trailing: _StatusPill(text: _statusText, accent: accent),
          ),
          const SizedBox(height: 14),
          const Text(_rollNumberLabel, style: AppTextStyles.metricLabel),
          const SizedBox(height: 2),
          Text(
            roll.generatedRollId,
            style: AppTextStyles.h2.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: accent.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          const Text(_weightLabel, style: AppTextStyles.metricLabel),
          const SizedBox(height: 2),
          if (weightKg != null)
            Text(
              // App-wide weight idiom: 3 decimals + Arabic كغ (e.g. 101.000 كغ).
              '${weightKg.toStringAsFixed(3)} كغ',
              style: AppTextStyles.metricValue,
            )
          else
            Text(
              _weightUnavailable,
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
