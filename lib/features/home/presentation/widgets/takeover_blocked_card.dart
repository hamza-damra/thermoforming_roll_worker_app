import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import 'takeover_strings.dart';

/// Card shown in place of the roll-work affordances (scan / mount / close /
/// reprint) when the backend reports that roll work is blocked — `blocked`
/// is `true` or the takeover has auto-released (spec §4.2 / §8).
///
/// It carries the backend [reason] when one is supplied, otherwise the
/// standard "line in handover" message.
class TakeoverBlockedCard extends StatelessWidget {
  const TakeoverBlockedCard({super.key, this.reason});

  /// Backend `blockedReason`, when present.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final String message = (reason != null && reason!.isNotEmpty)
        ? reason!
        : TakeoverStrings.blockedWork;
    return AppCard(
      borderRadius: 18,
      color: AppColors.offlineBg,
      borderColor: AppColors.offline.withValues(alpha: 0.4),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                size: 32,
                color: AppColors.offline,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.offline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
