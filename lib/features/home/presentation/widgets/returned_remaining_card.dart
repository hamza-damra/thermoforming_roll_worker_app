import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/info_row.dart';
import '../../domain/entities/shift_line_summary.dart';

/// Post-incompatible-product-switch card (handoff §3.4 / §5).
///
/// Surfaced when the Operator app changed the active product to one the
/// mounted roll cannot serve — the backend auto-closed the roll with
/// `إرجاع المتبقي` and cleared the mount. This card lets the worker:
///   - acknowledge the close,
///   - reprint the label for the returned remainder (when allowed).
///
/// Mirrors the structure of `ClosedRollSummaryCard` but is driven by an
/// SSE-pushed snapshot rather than a worker-initiated close.
class ReturnedRemainingCard extends StatelessWidget {
  const ReturnedRemainingCard({
    super.key,
    required this.snapshot,
    required this.onAcknowledge,
    this.onReprint,
    this.onPreview,
  });

  final ReturnedRemainingRoll snapshot;
  final VoidCallback onAcknowledge;

  /// Wired by the home screen to the existing label-reprint pipeline.
  /// Hidden when null or when [ReturnedRemainingRoll.canPrintLabel] is
  /// `false`.
  final ValueChanged<String>? onReprint;

  /// Wired by the home screen to push the on-screen preview. Optional.
  final ValueChanged<String>? onPreview;

  static const String _heading = 'تم إرجاع المتبقي بواسطة المشغل';
  static const String _detail =
      'قام المشغل بتغيير المنتج إلى منتج غير متوافق مع الرول. تم إغلاق الرول وإرجاع المتبقي تلقائيًا.';
  static const String _generatedRollId = 'رقم الرول';
  static const String _returnedLabel = 'الوزن المُعاد';
  static const String _oldProductLabel = 'المنتج السابق';
  static const String _newProductLabel = 'المنتج الجديد';
  static const String _ackLabel = 'حسنًا';
  static const String _reprintLabel = 'إعادة طباعة الليبل';
  static const String _previewLabel = 'معاينة الليبل';
  static const String _reprintHint = 'يمكن إعادة طباعة الليبل';

  String _kg(double v) => '${v.toStringAsFixed(3)} كغ';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.warning.withValues(alpha: 0.4),
      color: AppColors.offlineBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFE7BD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_return_rounded,
                  size: 24,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_heading, style: AppTextStyles.h3)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(_detail, style: AppTextStyles.body),
          const Divider(height: 24),
          InfoRow(
            label: _generatedRollId,
            value: snapshot.generatedRollId,
            icon: Icons.tag_rounded,
          ),
          InfoRow(
            label: _returnedLabel,
            value: _kg(snapshot.returnedWeightKg),
            icon: Icons.balance_rounded,
            valueStyle: AppTextStyles.metricValue,
          ),
          if (snapshot.oldProductName != null)
            InfoRow(
              label: _oldProductLabel,
              value: snapshot.oldProductName!,
              icon: Icons.history_rounded,
            ),
          if (snapshot.newProductName != null)
            InfoRow(
              label: _newProductLabel,
              value: snapshot.newProductName!,
              icon: Icons.inventory_2_outlined,
            ),
          if (snapshot.canPrintLabel) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.print_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(_reprintHint, style: AppTextStyles.label),
                  ),
                ],
              ),
            ),
            if (onReprint != null) ...[
              const SizedBox(height: 12),
              AppPrimaryButton(
                label: _reprintLabel,
                icon: Icons.print_rounded,
                onPressed: () => onReprint!(snapshot.generatedRollId),
              ),
            ],
            if (onPreview != null) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () => onPreview!(snapshot.generatedRollId),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text(_previewLabel),
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAcknowledge,
            icon: const Icon(Icons.check_rounded, size: 22),
            label: const Text(_ackLabel),
          ),
        ],
      ),
    );
  }
}
