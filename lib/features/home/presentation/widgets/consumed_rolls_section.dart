import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/util/roll_status_labels_ar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/info_row.dart';
import '../../domain/entities/shift_line_summary.dart';

/// Operator-shift-line-scoped list of the worker's closed rolls returned by
/// `/summary.consumedRolls` (V123).
///
/// Scoped by operator identity + the current operator shift-line/session, so it
/// survives a plain logout/login while the same `shiftLineId` stays active (a
/// new operator session / `shiftLineId` starts a fresh list) — hence the
/// "في هذه المناوبة" copy. Each item's `consumedWeightKg` is this worker's
/// per-interval contribution (not necessarily the whole roll, e.g. after a
/// takeover), rendered verbatim from the backend.
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
    this.accent,
  });

  final List<ConsumedRoll> rolls;

  /// Wired by the home screen to fire the existing label-reprint pipeline.
  /// Null disables reprint entirely (e.g., for tests/preview surfaces).
  final ValueChanged<String>? onReprint;

  /// Active line accent — tints the roll icon, the consumed-weight badge and
  /// the reprint affordances. Falls back to the brand primary.
  final Color? accent;

  static const String heading = 'الرولات المستهلكة في هذه المناوبة';
  static const String emptyState = 'لا توجد رولات مستهلكة في هذه المناوبة بعد';

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
              accent: accent,
            ),
            if (i < rolls.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ConsumedRollCard extends StatefulWidget {
  const _ConsumedRollCard({required this.roll, this.onReprint, this.accent});

  final ConsumedRoll roll;
  final ValueChanged<String>? onReprint;
  final Color? accent;

  @override
  State<_ConsumedRollCard> createState() => _ConsumedRollCardState();
}

class _ConsumedRollCardState extends State<_ConsumedRollCard> {
  bool _expanded = false;

  static String _kg(double v) => '${v.toStringAsFixed(3)} كغ';

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
    final Color accent = widget.accent ?? AppColors.primary;
    final String? typeLine = roll.rollTypeName.trim().isNotEmpty
        ? '${roll.rollTypeCode} • ${roll.rollTypeName}'
        : (roll.rollTypeCode.trim().isNotEmpty ? roll.rollTypeCode : null);

    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header: roll icon + serial (prominent) / type (secondary) +
              // optional reprint icon + expand chevron. The date moved to its
              // own line below so the serial/type never get squeezed/clipped.
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.archive_outlined,
                      size: 19,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          roll.generatedRollId,
                          style: AppTextStyles.h3.copyWith(
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (typeLine != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            typeLine,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_canReprint && !_expanded) ...<Widget>[
                    const SizedBox(width: 8),
                    _ReprintIconButton(accent: accent, onTap: _fireReprint),
                  ],
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Badges wrap to a second line on small screens — never overflow.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _Pill(
                    icon: Icons.local_fire_department_outlined,
                    text: _kg(roll.consumedWeightKg),
                    accent: accent,
                  ),
                  _Pill(
                    icon: Icons.flag_outlined,
                    text: closedReasonLabelAr(roll.closedReason),
                    accent: accent,
                    muted: true,
                  ),
                ],
              ),
              if (roll.endedAtDisplay.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        roll.endedAtDisplay,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? _ExpandedBody(
                        roll: roll,
                        kg: _kg,
                        accent: accent,
                        closedReason: closedReasonLabelAr(roll.closedReason),
                        remainderAction: remainderActionLabelAr(
                          roll.remainderAction,
                        ),
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

/// Small accent-tinted reprint icon button shown on collapsed cards.
class _ReprintIconButton extends StatelessWidget {
  const _ReprintIconButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(Icons.print_outlined, size: 18, color: accent),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.text,
    required this.accent,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final Color accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Color fg = muted ? AppColors.textSecondary : accent;
    final Color bg =
        muted ? AppColors.surfaceMuted : accent.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.label.copyWith(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
    required this.accent,
    required this.closedReason,
    required this.remainderAction,
    required this.showReprintButton,
    required this.onReprintTap,
  });

  final ConsumedRoll roll;
  final String Function(double) kg;
  final Color accent;
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
          // V123: this worker's per-interval contribution to the roll within
          // the current operator shift-line/session — NOT necessarily the whole
          // roll's start − end (e.g. after a takeover the incoming worker is
          // credited only the post-boundary delta). Rendered verbatim from the
          // backend; never recomputed client-side.
          label: 'الوزن المُستهلَك من الرول ضمن هذه المناوبة',
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
            color: accent,
            onPressed: onReprintTap,
          ),
        ],
      ],
    );
  }
}
