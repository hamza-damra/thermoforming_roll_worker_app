import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../domain/entities/line_takeover.dart';
import '../controllers/acknowledged_takeover_controller.dart';
import '../controllers/shift_line_summary_controller.dart';
import 'takeover_countdown.dart';
import 'takeover_strings.dart';

/// 10-minute pending window — the dialog countdown spans this.
const Duration kTakeoverPendingWindow = Duration(minutes: 10);

/// Shows the high-priority Line Takeover Request dialog (spec §4.1).
///
/// The dialog cannot be dismissed by tapping outside or the back button — the
/// roll worker must tap `حسناً`, which records the acknowledgement and
/// collapses the message into the persistent banner. The Roll Worker app
/// shows **no** accept/reject buttons.
Future<void> showTakeoverRequestDialog(
  BuildContext context, {
  required int shiftLineId,
  required LineTakeover takeover,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext _) =>
        _TakeoverRequestDialog(shiftLineId: shiftLineId, takeover: takeover),
  );
}

class _TakeoverRequestDialog extends ConsumerWidget {
  const _TakeoverRequestDialog({
    required this.shiftLineId,
    required this.takeover,
  });

  final int shiftLineId;
  final LineTakeover takeover;

  void _acknowledge(BuildContext context, WidgetRef ref) {
    final int? requestId = takeover.requestId;
    if (requestId != null) {
      ref
          .read(acknowledgedTakeoverProvider(shiftLineId).notifier)
          .acknowledge(requestId);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? expiry = takeover.effectivePendingExpiry;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: <Widget>[
              Icon(
                Icons.swap_horizontal_circle_outlined,
                color: AppColors.warning,
                size: 28,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(TakeoverStrings.title, style: AppTextStyles.h3),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(TakeoverStrings.body, style: AppTextStyles.body),
              if (takeover.currentOperatorName != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'المشغّل الحالي: ${takeover.currentOperatorName}',
                  style: AppTextStyles.caption,
                ),
              ],
              if (expiry != null) ...<Widget>[
                const SizedBox(height: 16),
                TakeoverCountdown(
                  target: expiry,
                  window: kTakeoverPendingWindow,
                  onExpired: () => ref
                      .read(
                        shiftLineSummaryControllerProvider(
                          shiftLineId,
                        ).notifier,
                      )
                      .refresh(),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: <Widget>[
            AppPrimaryButton(
              label: TakeoverStrings.acknowledge,
              icon: Icons.check_rounded,
              onPressed: () => _acknowledge(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
