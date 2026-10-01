import 'package:flutter/material.dart';

import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/info_row.dart';
import '../../domain/entities/roll_search_outcome.dart';
import '../roll_search_strings.dart';

/// Preview of one found roll: identity, production time, weight, lifecycle
/// state and whether it can be mounted on this line. The mount button exists
/// only when the backend says the roll is mountable; otherwise the refusal is
/// shown in the same Arabic the scan uses.
class RollSearchMatchCard extends StatelessWidget {
  const RollSearchMatchCard({
    super.key,
    required this.match,
    required this.onMount,
    this.isMounting = false,
    this.onShowRefusalDetails,
    this.accent,
  });

  final RollSearchMatch match;
  final VoidCallback onMount;
  final bool isMounting;

  /// Opens the scan's dialog for this refusal; `null` when the refusal has
  /// no dialog (its text is shown in full already).
  final VoidCallback? onShowRefusalDetails;

  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent ?? AppColors.primary;
    final String typeName =
        match.rollTypeDisplayName ?? match.rollTypeRollCode ?? '—';
    final String? typeCode =
        match.rollTypeRollCode != null &&
            match.rollTypeRollCode != match.rollTypeDisplayName
        ? match.rollTypeRollCode
        : null;
    final double? produced = match.producedWeightKg;
    final double? current = match.currentWeightKg;

    return AppCard(
      key: Key('rollSearchMatchCard.${match.generatedRollId}'),
      elevated: true,
      accent: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      RollSearchStrings.rollNumber,
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      match.generatedRollId,
                      textDirection: TextDirection.ltr,
                      style: AppTextStyles.h2.copyWith(letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
              _StateChip(
                label: match.consumptionStateLabel ?? match.consumptionState,
              ),
            ],
          ),
          const Divider(height: 20),
          if (match.producedAt != null)
            InfoRow(
              label: RollSearchStrings.producedAt,
              value: RollSearchStrings.productionTime(match.producedAt!),
            ),
          InfoRow(
            label: RollSearchStrings.rollType,
            value: typeCode == null ? typeName : '$typeName ($typeCode)',
          ),
          if (match.colorName != null)
            InfoRow(label: RollSearchStrings.color, value: match.colorName!),
          InfoRow(
            label: RollSearchStrings.productionKind,
            value: RollSearchStrings.productionKindLabel(match.productionKind),
          ),
          if (produced != null)
            InfoRow(
              label: RollSearchStrings.producedWeight,
              value: RollSearchStrings.kg(produced),
            ),
          if (current != null && current != produced)
            InfoRow(
              label: RollSearchStrings.currentWeight,
              value: RollSearchStrings.kg(current),
            ),
          const SizedBox(height: 12),
          if (match.mountable)
            const _Verdict(
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
              title: RollSearchStrings.mountable,
            )
          else
            _Verdict(
              icon: Icons.block_rounded,
              color: AppColors.error,
              title: RollSearchStrings.notMountable,
              reason: match.mountRefusal == null
                  ? null
                  : arabicMessageFor(match.mountRefusal!),
              onDetails: onShowRefusalDetails,
            ),
          if (match.mountable) ...<Widget>[
            const SizedBox(height: 14),
            AppPrimaryButton(
              key: const Key('rollSearchMatchCard.mount'),
              label: RollSearchStrings.mount,
              icon: Icons.download_rounded,
              color: tint,
              isLoading: isMounting,
              onPressed: isMounting ? null : onMount,
            ),
          ],
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: AppTextStyles.label),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.icon,
    required this.color,
    required this.title,
    this.reason,
    this.onDetails,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? reason;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (reason != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    reason!,
                    key: const Key('rollSearchMatchCard.refusal'),
                    style: AppTextStyles.body,
                  ),
                ],
                if (onDetails != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: onDetails,
                      child: const Text(RollSearchStrings.details),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
