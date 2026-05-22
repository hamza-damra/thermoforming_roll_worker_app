import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/line_takeover.dart';
import '../controllers/shift_line_summary_controller.dart';
import 'takeover_countdown.dart';
import 'takeover_request_dialog.dart';
import 'takeover_strings.dart';

/// 5-minute post-accept handover window — the accepted-banner countdown.
const Duration kTakeoverHandoverWindow = Duration(minutes: 5);

/// Persistent banner shown at the top of the home screen while a Line
/// Takeover Request is active (spec §4.2 / §5).
///
/// It replaces the blocking dialog after acknowledgement and morphs with the
/// backend status: pending (10-min countdown), accepted (5-min handover
/// countdown), or auto-released (no countdown, harder palette). It clears
/// itself for non-active statuses by rendering nothing.
class TakeoverBanner extends ConsumerWidget {
  const TakeoverBanner({
    super.key,
    required this.shiftLineId,
    required this.takeover,
  });

  final int shiftLineId;
  final LineTakeover takeover;

  void _refresh(WidgetRef ref) {
    ref
        .read(shiftLineSummaryControllerProvider(shiftLineId).notifier)
        .refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _BannerSpec? spec = _specFor(takeover);
    if (spec == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: spec.foreground.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(spec.icon, size: 20, color: spec.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      TakeoverStrings.title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: spec.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.message,
                      style: AppTextStyles.body.copyWith(
                        color: spec.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (spec.countdownTarget != null) ...<Widget>[
            const SizedBox(height: 12),
            TakeoverCountdown(
              target: spec.countdownTarget!,
              window: spec.countdownWindow,
              color: spec.foreground,
              onExpired: () => _refresh(ref),
            ),
          ],
        ],
      ),
    );
  }

  _BannerSpec? _specFor(LineTakeover t) {
    switch (t.status) {
      case TakeoverStatus.pending:
        return _BannerSpec(
          message: TakeoverStrings.body,
          icon: Icons.swap_horizontal_circle_outlined,
          background: AppColors.offlineBg,
          foreground: AppColors.offline,
          countdownTarget: t.effectivePendingExpiry,
          countdownWindow: kTakeoverPendingWindow,
        );
      case TakeoverStatus.accepted:
        return _BannerSpec(
          message: TakeoverStrings.acceptedBanner,
          icon: Icons.hourglass_bottom_rounded,
          background: AppColors.offlineBg,
          foreground: AppColors.offline,
          countdownTarget: t.effectiveHandoverExpiry,
          countdownWindow: kTakeoverHandoverWindow,
        );
      case TakeoverStatus.timeoutAutoReleased:
      case TakeoverStatus.postAcceptTimeoutAutoReleased:
        return const _BannerSpec(
          message: TakeoverStrings.autoReleasedBanner,
          icon: Icons.lock_clock_rounded,
          background: AppColors.errorBg,
          foreground: AppColors.error,
          countdownTarget: null,
          countdownWindow: Duration.zero,
        );
      case TakeoverStatus.rejected:
      case TakeoverStatus.completed:
      case TakeoverStatus.cancelled:
      case TakeoverStatus.unknown:
        return null;
    }
  }
}

class _BannerSpec {
  const _BannerSpec({
    required this.message,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.countdownTarget,
    required this.countdownWindow,
  });

  final String message;
  final IconData icon;
  final Color background;
  final Color foreground;
  final DateTime? countdownTarget;
  final Duration countdownWindow;
}
