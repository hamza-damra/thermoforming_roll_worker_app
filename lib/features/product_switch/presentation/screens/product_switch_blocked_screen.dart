import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/info_row.dart';
import '../../../roll_scan/domain/entities/mounted_roll.dart';

/// Backend-gap blocked screen for the product-switch flow.
///
/// The Roll Worker app must only offer products that are compatible with
/// the currently mounted roll's `RollType`. The dedicated backend endpoint
///
///   `GET /api/v1/thermoforming-roll-app/shift-lines/{shiftLineId}/product-switch-options`
///
/// has not shipped yet (requirements §11 / §24 gap #2). Until it does,
/// this app deliberately ships a passive shell — there is no product
/// picker, no manual product-id entry, no fallback to a generic active-
/// products list, and no submit path that can reach the backend.
///
/// The submit button is rendered visibly disabled so the worker can see
/// where the action will live without being able to invoke it. When the
/// backend ships the picker endpoint, Stage 7+ will replace this screen
/// with a real product-switch dialog.
class ProductSwitchBlockedScreen extends StatelessWidget {
  const ProductSwitchBlockedScreen({super.key, this.mountedRoll});

  /// Optional snapshot of the currently mounted roll. When provided, the
  /// screen surfaces the current product and roll-type for the worker's
  /// awareness; never used to drive any actionable picker.
  final MountedRoll? mountedRoll;

  // ─── Prescribed Arabic copy ─────────────────────────────────────────────
  static const String title = 'تغيير المنتج';
  static const String blockedTitle = 'تغيير المنتج غير متاح حاليًا';
  static const String blockedBody =
      'بانتظار دعم الخادم لعرض المنتجات المتوافقة مع الرول الحالي.';
  static const String helper =
      'لا يمكن تغيير المنتج قبل توفر قائمة المنتجات المتوافقة من الخادم.';
  static const String submitLabel = 'تغيير المنتج';
  static const String currentProductLabel = 'المنتج الحالي';
  static const String currentRollTypeLabel = 'نوع الرول الحالي';

  @override
  Widget build(BuildContext context) {
    final MountedRoll? roll = mountedRoll;
    return AppScaffold(
      title: title,
      body: ListView(
        children: [
          const SizedBox(height: 12),
          if (roll != null) ...[
            _CurrentContextCard(roll: roll),
            const SizedBox(height: 16),
          ],
          _BlockedCard(),
          const SizedBox(height: 24),
          // Visibly disabled — no submit path reaches the backend in this
          // build. The button exists only to mark where the action will
          // live once the backend ships the picker.
          const AppPrimaryButton(
            label: submitLabel,
            icon: Icons.swap_horiz_rounded,
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

class _CurrentContextCard extends StatelessWidget {
  const _CurrentContextCard({required this.roll});

  final MountedRoll roll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            label: ProductSwitchBlockedScreen.currentProductLabel,
            value: roll.productTypeName,
            icon: Icons.inventory_2_rounded,
          ),
          InfoRow(
            label: ProductSwitchBlockedScreen.currentRollTypeLabel,
            value: roll.rollTypeDisplayName,
            icon: Icons.style_rounded,
          ),
        ],
      ),
    );
  }
}

class _BlockedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderColor: AppColors.warning.withValues(alpha: 0.4),
      color: AppColors.offlineBg,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.hourglass_empty_rounded,
                size: 22,
                color: AppColors.offline,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  ProductSwitchBlockedScreen.blockedTitle,
                  style: AppTextStyles.h3,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            ProductSwitchBlockedScreen.blockedBody,
            style: AppTextStyles.body,
          ),
          SizedBox(height: 8),
          Text(ProductSwitchBlockedScreen.helper, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
