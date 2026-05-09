import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/info_row.dart';
import '../../../printer/pipeline/label_renderer.dart';
import '../../domain/entities/roll_label.dart';
import 'reprint_badge.dart';

/// On-screen visual preview of the roll sticker that the worker is about
/// to (re)print. Mirrors the canonical layout used by the production
/// rasteriser (QR + roll details), so warehouses recognise the same
/// shape when comparing the on-screen preview with the physical sticker.
///
/// This widget never rasterises — the QR draws via `CustomPaint` from the
/// shared `qr` package. It's safe to use in widget tests.
class LabelStickerWidget extends StatelessWidget {
  const LabelStickerWidget({super.key, required this.label});

  final RollLabel label;

  static const String _heading = 'معاينة الليبل';
  static const String _generatedRollIdLabel = 'رقم الرول';
  static const String _rollTypeLabel = 'نوع الرول';
  static const String _colorLabel = 'اللون';
  static const String _weightLabel = 'الوزن';
  static const String _lengthLabel = 'الطول';
  static const String _serialLabel = 'الرقم التسلسلي';
  static const String _lastKnownWeightLabel = 'الوزن المعروف الأخير';

  String _formatKg(double kg) => '${kg.toStringAsFixed(3)} كغ';
  String _formatM(double m) => '${m.toStringAsFixed(3)} م';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text(_heading, style: AppTextStyles.h3)),
              ReprintBadge(consumptionState: label.consumptionState),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 220,
                  maxHeight: 220,
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(
                    painter: QrPreviewPainter(value: label.generatedRollId),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              label.generatedRollId,
              style: AppTextStyles.h2.copyWith(
                letterSpacing: 2,
                color: AppColors.textPrimary,
              ),
              textDirection: TextDirection.ltr,
            ),
          ),
          const Divider(height: 24),
          InfoRow(
            label: _generatedRollIdLabel,
            value: label.generatedRollId,
            icon: Icons.tag_rounded,
          ),
          InfoRow(
            label: _serialLabel,
            value: label.serialNumber.toString(),
            icon: Icons.numbers_rounded,
          ),
          InfoRow(
            label: _rollTypeLabel,
            value: label.rollTypeDisplayName,
            icon: Icons.style_rounded,
          ),
          InfoRow(
            label: _colorLabel,
            value: label.colorName,
            icon: Icons.palette_rounded,
          ),
          InfoRow(
            label: _weightLabel,
            value: _formatKg(label.actualWeightKg),
            icon: Icons.scale_rounded,
          ),
          InfoRow(
            label: _lengthLabel,
            value: _formatM(label.actualLengthM),
            icon: Icons.straighten_rounded,
          ),
          InfoRow(
            label: _lastKnownWeightLabel,
            value: _formatKg(label.lastKnownWeightKg),
            icon: Icons.balance_rounded,
            valueStyle: AppTextStyles.metricValue,
          ),
        ],
      ),
    );
  }
}
