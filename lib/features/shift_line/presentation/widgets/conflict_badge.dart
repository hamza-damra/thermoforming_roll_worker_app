import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Advisory chip rendered on a picker row when the backend reports an
/// existing roll-worker session held by a different operator.
///
/// The row stays selectable (per handoff §2.1) — this badge just informs
/// the worker before they commit PIN entry. After PIN, a conflict comes
/// back as `ROLL_WORKER_SESSION_LINE_USED_BY_OTHER_WORKER` and the picker
/// drops the offending id from the selection.
class ConflictBadge extends StatelessWidget {
  const ConflictBadge({super.key, required this.operatorName});

  final String operatorName;

  static const String prefix = 'مستخدم من: ';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.offlineBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.offline.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_outline_rounded,
            size: 16,
            color: AppColors.offline,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$prefix$operatorName',
              style: AppTextStyles.caption.copyWith(color: AppColors.offline),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
