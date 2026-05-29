import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Blocking, in-place "machine unavailable / waiting" overlay.
///
/// Rendered as a `Positioned.fill` child of the per-machine dashboard
/// `Stack` when the machine has no active operator, is in handover, or is
/// backend-blocked. Mirrors the reference app's waiting card: dimmed
/// background, centered amber card, informational copy, a small waiting
/// spinner row, and a manual refresh button (no acknowledge / dismiss).
class MachineWaitingCard extends StatelessWidget {
  const MachineWaitingCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.person_off_outlined,
    this.onRefresh,
    this.showWaitingRow = true,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRefresh;
  final bool showWaitingRow;

  static const String waitingRowText = 'بانتظار توفر المشغّل…';
  static const String refreshLabel = 'تحديث';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.22),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: AppColors.accentDark, size: 40),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.offlineBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.offline,
                          ),
                        ),
                      ),
                      if (showWaitingRow) ...<Widget>[
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.accentDark,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(waitingRowText, style: AppTextStyles.label),
                          ],
                        ),
                      ],
                      if (onRefresh != null) ...<Widget>[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onRefresh,
                            icon: const Icon(Icons.refresh_rounded, size: 22),
                            label: const Text(refreshLabel),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
