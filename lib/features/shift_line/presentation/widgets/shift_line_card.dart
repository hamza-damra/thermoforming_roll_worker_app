import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/info_row.dart';
import '../../domain/entities/roll_worker_bootstrap_line.dart';
import 'line_unavailable_dialog.dart';
import 'line_waiting_status.dart';

/// Reusable row widget used by the pre-login picker AND the in-session
/// "add another line" sheet.
///
/// Extracted from `active_shift_line_picker_screen.dart` so both surfaces
/// render identical card visuals; the original `_ShiftLineCard` now
/// delegates to this widget.
class ShiftLineCard extends StatelessWidget {
  const ShiftLineCard({
    super.key,
    required this.line,
    required this.selected,
    required this.conflicted,
    required this.onToggle,
    this.ownedByMe = false,
    this.palletizingLineLabel = 'خط الطبليات المرتبط',
    this.currentProductLabel = 'المنتج الحالي',
    this.operatorLabel = 'المشغّل',
    this.currentRollHeading = 'الرول الحالي',
    this.rollIdLabel = 'رقم الرول',
    this.rollTypeLabel = 'نوع الرول',
    this.currentWeightLabel = 'الوزن الحالي',
    this.missingValue = '—',
    this.waitingProduct = 'بانتظار المنتج',
    this.waitingOperator = 'لا يوجد مشغّل حالياً',
    this.ownedByMeLabel = 'أنت تعمل على هذا الخط',
  });

  final RollWorkerBootstrapLine line;
  final bool selected;
  final bool conflicted;
  final ValueChanged<int> onToggle;

  /// When `true`, renders the "أنت تعمل على هذا الخط" ownership chip next to
  /// the line title. Parents compute this from
  /// `multiLineSessionRegistryProvider.activeShiftLineIds`.
  final bool ownedByMe;

  final String palletizingLineLabel;
  final String currentProductLabel;
  final String operatorLabel;
  final String currentRollHeading;
  final String rollIdLabel;
  final String rollTypeLabel;
  final String currentWeightLabel;
  final String missingValue;
  final String waitingProduct;
  final String waitingOperator;
  final String ownedByMeLabel;

  String get _thermoLine {
    final String name = line.lineName.trim();
    final String code = line.lineCode.trim();
    if (name.isNotEmpty && code.isNotEmpty) return '$name ($code)';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return 'ماكنة ${line.machineNumber ?? line.thermoformingLineId}';
  }

  String get _palletizingLine {
    final String name = (line.palletizingLineName ?? '').trim();
    final String code = (line.palletizingLineCode ?? '').trim();
    if (name.isNotEmpty && code.isNotEmpty) return '$name ($code)';
    if (name.isNotEmpty) return name;
    if (code.isNotEmpty) return code;
    return missingValue;
  }

  static String formatWeight(double? kg, {String missingValue = '—'}) {
    if (kg == null) return missingValue;
    final String trimmed = kg
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$trimmed kg';
  }

  @override
  Widget build(BuildContext context) {
    final bool selectable = line.selectable && line.shiftLineId != null;

    final String product =
        line.currentProductTypeName ??
        (selectable ? missingValue : waitingProduct);
    final String operator =
        line.activeOperatorName ??
        (selectable ? missingValue : waitingOperator);

    final TextStyle? mutedValue = selectable
        ? null
        : AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary);

    final BoxBorder? border = conflicted
        ? Border.all(color: AppColors.warning, width: 2)
        : null;

    final Widget card = Container(
      decoration: border == null
          ? null
          : BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(14),
            ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (selectable)
                  Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(line.shiftLineId!),
                  )
                else
                  const SizedBox(width: 4, height: 48),
                Expanded(
                  child: Text(_thermoLine, style: AppTextStyles.h3),
                ),
                if (ownedByMe) _OwnedByMePill(label: ownedByMeLabel),
              ],
            ),
            if (!selectable) ...[
              const SizedBox(height: 2),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _StatusPill(
                  label: LineWaitingStatus.pillLabelFor(line),
                ),
              ),
            ],
            const SizedBox(height: 8),
            InfoRow(
              label: palletizingLineLabel,
              value: _palletizingLine,
              icon: Icons.local_shipping_rounded,
            ),
            InfoRow(
              label: currentProductLabel,
              value: product,
              icon: Icons.category_rounded,
              valueStyle: mutedValue,
            ),
            InfoRow(
              label: operatorLabel,
              value: operator,
              icon: Icons.person_rounded,
              valueStyle: mutedValue,
            ),
            if (line.hasMountedRoll) ...[
              const Divider(height: 24),
              Text(currentRollHeading, style: AppTextStyles.h3),
              const SizedBox(height: 4),
              InfoRow(
                label: rollIdLabel,
                value: line.currentRollGeneratedRollId ?? missingValue,
                icon: Icons.qr_code_rounded,
              ),
              InfoRow(
                label: rollTypeLabel,
                value: line.currentRollTypeName ??
                    line.currentRollTypeCode ??
                    missingValue,
                icon: Icons.label_outline_rounded,
              ),
              InfoRow(
                label: currentWeightLabel,
                value: formatWeight(
                  line.currentRollLastKnownWeightKg,
                  missingValue: missingValue,
                ),
                icon: Icons.scale_rounded,
              ),
            ],
          ],
        ),
      ),
    );

    return InkWell(
      onTap: selectable
          ? () => onToggle(line.shiftLineId!)
          : () => showLineUnavailableDialog(context, line: line),
      borderRadius: BorderRadius.circular(14),
      child: card,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 14,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnedByMePill extends StatelessWidget {
  const _OwnedByMePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
