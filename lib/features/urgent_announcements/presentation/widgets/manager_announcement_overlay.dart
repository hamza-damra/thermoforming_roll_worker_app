import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/manager_announcement.dart';
import '../controllers/manager_announcement_controller.dart';
import '../controllers/manager_announcement_state.dart';
import 'urgent_announcement_strings.dart';

/// Blocking, non-dismissible modal for a sanitized urgent-manager notice.
///
/// Rendered as a `Positioned.fill` child of the app shell `Stack` (never
/// `showDialog`) — the same scrim+card pattern as `RollWorkerAuthOverlay`. It
/// dims the whole dashboard so scanning / mounting is blocked until the worker
/// taps "فهمت" AND the server confirms the ack.
///
/// PRIVACY: only the fixed [UrgentAnnouncementStrings] title/message are
/// shown, plus the server's `createdAtDisplay` as secondary metadata. The real
/// manager body/sender is never rendered (and is not even parsed — see
/// `ManagerAnnouncement`).
class ManagerAnnouncementOverlay extends ConsumerWidget {
  const ManagerAnnouncementOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ManagerAnnouncementState state = ref.watch(
      managerAnnouncementControllerProvider,
    );
    final ManagerAnnouncement? front = state.front;
    // Defensive: the overlay is only mounted when there is a pending notice,
    // but guard so a transient empty state never paints a blank scrim.
    if (front == null) return const SizedBox.shrink();

    const Color accent = AppColors.warning;

    return PopScope(
      // Hardware / gesture back cannot dismiss — the only exit is a confirmed
      // ack.
      canPop: false,
      child: GestureDetector(
        // Absorb taps on the dimmed background — no outside dismiss.
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
                      color: accent.withValues(alpha: 0.22),
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
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notification_important_rounded,
                          color: accent,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        UrgentAnnouncementStrings.title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        UrgentAnnouncementStrings.message,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                      if (front.createdAtDisplay != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          front.createdAtDisplay!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                        ),
                      ],
                      if (state.ackError != null) ...<Widget>[
                        const SizedBox(height: 16),
                        const _AckErrorBox(),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: state.acking
                              ? null
                              : () => ref
                                    .read(
                                      managerAnnouncementControllerProvider
                                          .notifier,
                                    )
                                    .acknowledgeFront(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            disabledBackgroundColor: accent.withValues(
                              alpha: 0.5,
                            ),
                            foregroundColor: AppColors.textOnPrimary,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: state.acking
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.textOnPrimary,
                                    ),
                                  ),
                                )
                              : const Text(
                                  UrgentAnnouncementStrings.ackButton,
                                  style: AppTextStyles.button,
                                ),
                        ),
                      ),
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

/// Inline retry message shown when the ack call fails — mirrors the error box
/// in `RollWorkerAuthOverlay`.
class _AckErrorBox extends StatelessWidget {
  const _AckErrorBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline_rounded, size: 20, color: AppColors.error),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              UrgentAnnouncementStrings.ackError,
              style: AppTextStyles.errorInline,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
}
