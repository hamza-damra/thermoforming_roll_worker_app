import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/roll_label.dart';

/// Badge prescribed by requirements §12: indicates whether the sticker is
/// being reprinted after a partial return or before grinding.
///
///   - PARTIALLY_RETURNED → "إعادة طباعة بعد الإرجاع"
///   - SENT_TO_GRINDING   → "إعادة طباعة قبل الجرش"
///
/// For any other consumption state (which shouldn't happen — backend
/// rejects with `ROLL_LABEL_REPRINT_NOT_AVAILABLE`), the badge falls back
/// to the generic prescribed copy "إعادة طباعة الليبل".
class ReprintBadge extends StatelessWidget {
  const ReprintBadge({super.key, required this.consumptionState});

  final RollConsumptionState consumptionState;

  static const String _afterReturn = 'إعادة طباعة بعد الإرجاع';
  static const String _beforeGrinding = 'إعادة طباعة قبل الجرش';
  static const String _generic = 'إعادة طباعة الليبل';

  String get label => switch (consumptionState) {
    RollConsumptionState.partiallyReturned => _afterReturn,
    RollConsumptionState.sentToGrinding => _beforeGrinding,
    _ => _generic,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
