import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../domain/entities/shift_line_summary.dart';

/// Current mounted-roll card driven by [SummaryMountedRoll].
///
/// Deliberately minimal: the 12-digit roll number and an "in consumption"
/// status pill only. Roll type and current weight were removed — the worker
/// identifies the mounted roll by its serial, and the product/allowed-rolls
/// card above already carries the type context. Rendered only when the backend
/// returns a non-null `mountedRoll` in the summary response.
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

  @override
  Widget build(BuildContext context) {
    final Color accent = accentColor ?? AppColors.primary;

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
