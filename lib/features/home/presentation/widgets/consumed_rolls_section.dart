import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/info_row.dart';
import '../../domain/entities/shift_line_summary.dart';

/// Session-scoped list of closed rolls returned by `/summary.consumedRolls`.
///
/// Each card is collapsed by default so the worker can scan the recent
/// roll history at a glance. Tapping expands the card to reveal full
/// metadata + the optional reprint action.
///
/// Reprint visibility rule (per business decision): only rolls whose
/// `remainderAction` is `RETURN` or `GRINDING` have a physical remainder
/// worth labelling. Fully-consumed rolls (`NONE` / `FULL_CONSUMPTION`)
/// never show a reprint affordance.
class ConsumedRollsSection extends StatelessWidget {
  const ConsumedRollsSection({
    super.key,
    required this.rolls,
    this.onReprint,
  });

  final List<ConsumedRoll> rolls;

  /// Wired by the home screen to fire the existing label-reprint pipeline.
  /// Null disables reprint entirely (e.g., for tests/preview surfaces).
  final ValueChanged<String>? onReprint;

  static const String heading = 'الرولات المستهلكة في هذه الجلسة';
  static const String emptyState = 'لا توجد رولات مستهلكة في هذه الجلسة';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsetsDirectional.only(start: 4, bottom: 8),
          child: Text(heading, style: AppTextStyles.metricLabel),
        ),
        if (rolls.isEmpty)
          AppCard(
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    emptyState,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (int i = 0; i < rolls.length; i++) ...<Widget>[
            _ConsumedRollCard(
              roll: rolls[i],
              onReprint: onReprint,
            ),
            if (i < rolls.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ConsumedRollCard extends StatefulWidget {
  const _ConsumedRollCard({required this.roll, this.onReprint});

  final ConsumedRoll roll;
  final ValueChanged<String>? onReprint;

  @override
  State<_ConsumedRollCard> createState() => _ConsumedRollCardState();
}

class _ConsumedRollCardState extends State<_ConsumedRollCard> {
  bool _expanded = false;

  static String _kg(double v) => '${v.toStringAsFixed(3)} كغ';

  static String closedReasonLabel(String wire) {
    return switch (wire) {
      'FULL_CONSUMPTION' => 'استهلاك كامل',
      'PARTIAL_RETURN' => 'إرجاع جزئي',
      'PARTIAL_GRINDING' => 'جرش جزئي',
      _ => wire,
    };
  }

  static String remainderActionLabel(String wire) {
    return switch (wire) {
      'NONE' => 'بدون متبقي',
      'RETURN' => 'إرجاع المتبقي',
      'GRINDING' => 'إرسال للجرش',
      _ => wire,
    };
  }

  /// Backend authoritative when `reprintAvailable` is present. Older backends
  /// that don't expose the flag fall back to inferring from `remainderAction`
  /// + `remainingWeightKg`, which is functionally equivalent today but will
  /// stop matching once the backend evolves the rule.
  bool get _canReprint {
    if (widget.onReprint == null) return false;
    final ConsumedRoll roll = widget.roll;
    final bool? backendFlag = roll.reprintAvailable;
    if (backendFlag != null) return backendFlag;
    return _legacyInference(roll);
  }

  static bool _legacyInference(ConsumedRoll roll) {
    if (roll.remainderAction != 'RETURN' && roll.remainderAction != 'GRINDING') {
      return false;
    }
    final double? remaining = roll.remainingWeightKg;
    if (remaining != null && remaining <= 0) return false;
    return true;
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  void _fireReprint() {
    final ValueChanged<String>? cb = widget.onReprint;
    if (cb == null) return;
    cb(widget.roll.generatedRollId);
  }

  @override
  Widget build(BuildContext context) {
    final ConsumedRoll roll = widget.roll;
    final String typeLine = roll.rollTypeName.isNotEmpty
        ? '${roll.rollTypeCode} • ${roll.rollTypeName}'
        : roll.rollTypeCode;

    return AppCard(
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(
                typeLine: typeLine,
                generatedRollId: roll.generatedRollId,
                endedAtDisplay: roll.endedAtDisplay,
                expanded: _expanded,
              ),
              const SizedBox(height: 8),
              _CompactRow(
                consumedKg: _kg(roll.consumedWeightKg),
                closedReason: closedReasonLabel(roll.closedReason),
                showReprintIcon: _canReprint && !_expanded,
                onReprintIconTap: _fireReprint,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                child: _expanded
                    ? _ExpandedBody(
                        roll: roll,
                        kg: _kg,
                        closedReason: closedReasonLabel(roll.closedReason),
                        remainderAction: remainderActionLabel(roll.remainderAction),
                        showReprintButton: _canReprint,
                        onReprintTap: _fireReprint,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.typeLine,
    required this.generatedRollId,
    required this.endedAtDisplay,
    required this.expanded,
  });

  final String typeLine;
  final String generatedRollId;
  final String endedAtDisplay;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.archive_outlined,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                typeLine,
                style: AppTextStyles.h3.copyWith(fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              const SizedBox(height: 2),
              Text(
                generatedRollId,
                style: AppTextStyles.label.copyWith(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          endedAtDisplay,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: 4),
        AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 180),
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.consumedKg,
    required this.closedReason,
    required this.showReprintIcon,
    required this.onReprintIconTap,
  });

  final String consumedKg;
  final String closedReason;
  final bool showReprintIcon;
  final VoidCallback onReprintIconTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _Pill(
          icon: Icons.local_fire_department_outlined,
          text: consumedKg,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: _Pill(
            icon: Icons.flag_outlined,
            text: closedReason,
            muted: true,
          ),
        ),
        if (showReprintIcon) ...<Widget>[
          const Spacer(),
          InkResponse(
            onTap: onReprintIconTap,
            radius: 22,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.print_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.muted = false});

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Color fg = muted ? AppColors.textSecondary : AppColors.primaryDark;
    final Color bg = muted ? AppColors.surfaceMuted : AppColors.primaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.label.copyWith(color: fg, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({
    required this.roll,
    required this.kg,
    required this.closedReason,
    required this.remainderAction,
    required this.showReprintButton,
    required this.onReprintTap,
  });

  final ConsumedRoll roll;
  final String Function(double) kg;
  final String closedReason;
  final String remainderAction;
  final bool showReprintButton;
  final VoidCallback onReprintTap;

  static const String _reprintLabel = 'إعادة طباعة الليبل';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Divider(height: 20),
        InfoRow(
          label: 'الوزن الابتدائي',
          value: kg(roll.startWeightKg),
          icon: Icons.scale_outlined,
        ),
        InfoRow(
          label: 'الوزن المستهلك',
          value: kg(roll.consumedWeightKg),
          icon: Icons.local_fire_department_outlined,
          valueStyle: AppTextStyles.metricValue,
        ),
        if (roll.remainingWeightKg != null)
          InfoRow(
            label: 'الوزن المتبقي',
            value: kg(roll.remainingWeightKg!),
            icon: Icons.balance_rounded,
          ),
        InfoRow(
          label: 'سبب الإغلاق',
          value: closedReason,
          icon: Icons.flag_outlined,
        ),
        InfoRow(
          label: 'إجراء المتبقي',
          value: remainderAction,
          icon: Icons.alt_route_outlined,
        ),
        if (showReprintButton) ...<Widget>[
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: _reprintLabel,
            icon: Icons.print_rounded,
            onPressed: onReprintTap,
          ),
        ],
      ],
    );
  }
}
