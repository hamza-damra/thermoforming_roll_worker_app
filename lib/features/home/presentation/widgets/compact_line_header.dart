import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// One-row compact line header: `[TH-01]  خط التشكيل 1`.
///
/// [lineCode] and [lineName] are nullable while the summary is loading.
/// [lineIndex] provides the 1-based fallback label (`خط 1`) when code is null.
class CompactLineHeader extends StatelessWidget {
  const CompactLineHeader({
    super.key,
    required this.lineCode,
    required this.lineName,
    required this.lineIndex,
  });

  final String? lineCode;
  final String? lineName;
  final int lineIndex;

  @override
  Widget build(BuildContext context) {
    final String codeText = lineCode ?? 'خط $lineIndex';
    final String nameText = lineName ?? '';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            codeText,
            style: AppTextStyles.label.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (nameText.isNotEmpty) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nameText,
              style: AppTextStyles.bodyLarge,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ],
    );
  }
}
