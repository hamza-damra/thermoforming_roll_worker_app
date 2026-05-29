import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/util/arabic_relative_time.dart';
import '../../../../core/widgets/app_card.dart';

/// Single expandable card for the roll worker's session — replaces the former
/// separate "المشغل المناوب" + "موظف الرولات" cards.
///
/// Collapsed (default): the roll worker name + an inline `مغادرة الآن` action.
/// Expanded: the current operator name and how long ago the session started
/// (Arabic relative time). Smooth `AnimatedSize` expansion; the whole card is
/// the toggle, while the leave button consumes its own taps.
class RollWorkerSessionCard extends StatefulWidget {
  const RollWorkerSessionCard({
    super.key,
    required this.workerName,
    required this.operatorName,
    required this.sessionStartedAt,
    this.onLeave,
    this.isLeaving = false,
    this.accent,
    this.initiallyExpanded = false,
    this.now,
  });

  /// Logged-in roll worker name, or `null` when none is logged in.
  final String? workerName;

  /// Thermoforming operator currently owning the line (shown when expanded).
  final String? operatorName;

  /// Raw session-start timestamp — rendered as Arabic relative time.
  final DateTime? sessionStartedAt;

  /// Opens the leave confirmation. `null` hides the leave action.
  final VoidCallback? onLeave;
  final bool isLeaving;
  final Color? accent;

  /// Mostly for tests/golden states — defaults to collapsed.
  final bool initiallyExpanded;

  /// Injectable clock for the relative-time label (tests). Defaults to
  /// `DateTime.now()` at build time.
  final DateTime? now;

  static const String emptyState = 'لا يوجد موظف رولات مسجل حالياً';
  static const String leaveLabel = 'مغادرة الآن';
  static const String operatorLabel = 'المشغل الحالي';
  static const String sessionStartLabel = 'بداية الجلسة';
  static const String noOperator = 'لا يوجد مشغل حالياً';
  static const String noSession = '—';

  @override
  State<RollWorkerSessionCard> createState() => _RollWorkerSessionCardState();
}

class _RollWorkerSessionCardState extends State<RollWorkerSessionCard> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final Color color = widget.accent ?? AppColors.primary;
    final String? name = _clean(widget.workerName);
    final bool loggedIn = name != null;
    final String? operatorName = _clean(widget.operatorName);
    final DateTime? startedAt = widget.sessionStartedAt;

    return AppCard(
      elevated: true,
      accent: color,
      borderRadius: 18,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.badge_rounded, size: 21, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name ?? RollWorkerSessionCard.emptyState,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: loggedIn
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onLeave != null) ...<Widget>[
                    const SizedBox(width: 6),
                    _LeaveButton(
                      onPressed: widget.isLeaving ? null : widget.onLeave,
                      isLeaving: widget.isLeaving,
                    ),
                  ],
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: color,
                      size: 24,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.engineering_rounded,
                            label: RollWorkerSessionCard.operatorLabel,
                            value: operatorName ??
                                RollWorkerSessionCard.noOperator,
                            accent: color,
                            muted: operatorName == null,
                          ),
                          const SizedBox(height: 10),
                          _DetailRow(
                            icon: Icons.schedule_rounded,
                            label: RollWorkerSessionCard.sessionStartLabel,
                            value: startedAt != null
                                ? formatArabicRelativeTime(
                                    startedAt,
                                    now: widget.now ?? DateTime.now(),
                                  )
                                : RollWorkerSessionCard.noSession,
                            accent: color,
                            muted: startedAt == null,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _clean(String? v) =>
      (v != null && v.trim().isNotEmpty) ? v.trim() : null;
}

/// Label + value row used in the expanded section. Value is end-aligned (left
/// in RTL) and wraps to a second line rather than clipping.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              color: muted ? AppColors.textSecondary : AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Compact red "leave now" affordance — mirrors the Palletizing app button.
class _LeaveButton extends StatelessWidget {
  const _LeaveButton({required this.onPressed, required this.isLeaving});

  final VoidCallback? onPressed;
  final bool isLeaving;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
        disabledForegroundColor: AppColors.error.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: isLeaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
              ),
            )
          : const Icon(Icons.logout_rounded, size: 18),
      label: Text(
        RollWorkerSessionCard.leaveLabel,
        style: AppTextStyles.body.copyWith(
          color: AppColors.error,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
