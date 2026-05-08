import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/info_row.dart';
import '../../domain/entities/mounted_roll.dart';

/// Active mount card. Shows the worker the roll currently in consumption on
/// their line — generatedRollId, product, state, last known weight.
class MountCard extends StatelessWidget {
  const MountCard({super.key, required this.roll});

  final MountedRoll roll;

  static const String _heading = 'الرول الحالي';
  static const String _generatedRollId = 'رقم الرول';
  static const String _product = 'المنتج الحالي';
  static const String _rollType = 'نوع الرول';
  static const String _color = 'اللون';
  static const String _state = 'حالة الرول';
  static const String _lastKnownWeight = 'الوزن المعروف الأخير';
  static const String _stateInConsumption = 'قيد الاستهلاك';

  String _stateLabel(String wire) =>
      wire == 'IN_CONSUMPTION' ? _stateInConsumption : wire;

  String _formatKg(double kg) {
    final String s = kg.toStringAsFixed(3);
    return '$s كغ';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(_heading, style: AppTextStyles.label),
                    const SizedBox(height: 2),
                    Text(roll.generatedRollId, style: AppTextStyles.h3),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          InfoRow(
            label: _generatedRollId,
            value: roll.generatedRollId,
            icon: Icons.tag_rounded,
          ),
          InfoRow(
            label: _product,
            value: roll.productTypeName,
            icon: Icons.inventory_2_rounded,
          ),
          InfoRow(
            label: _rollType,
            value: roll.rollTypeDisplayName,
            icon: Icons.style_rounded,
          ),
          InfoRow(
            label: _color,
            value: roll.colorName,
            icon: Icons.palette_rounded,
          ),
          InfoRow(
            label: _state,
            value: _stateLabel(roll.state),
            icon: Icons.play_circle_outline_rounded,
          ),
          InfoRow(
            label: _lastKnownWeight,
            value: _formatKg(roll.lastKnownWeightKg),
            icon: Icons.scale_rounded,
            valueStyle: AppTextStyles.metricValue,
          ),
        ],
      ),
    );
  }
}
