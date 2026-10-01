import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';

/// Read-only production note of the mounted roll (V215), shown directly under
/// `CompactMountedRollCard`.
///
/// The note was typed by the Roll Production operator when the physical roll
/// was registered. It is informational only: neutral tone (never error red),
/// no edit/dismiss, and the full text is wrapped — never ellipsized — so a
/// 500-char multi-line note simply grows the card inside the scrolling list.
/// Callers render it only when `SummaryMountedRoll.visibleProductionNote` is
/// non-null; there is no empty/placeholder state.
class MountedRollNoteCard extends StatelessWidget {
  const MountedRollNoteCard({super.key, required this.note});

  final String note;

  static const String title = 'ملاحظة على الرول';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceMuted,
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(
            title: title,
            icon: Icons.sticky_note_2_outlined,
            accent: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            note,
            textDirection: TextDirection.rtl,
            softWrap: true,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
