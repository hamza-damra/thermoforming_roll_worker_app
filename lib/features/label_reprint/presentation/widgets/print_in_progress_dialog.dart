import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../printer/presentation/screens/printer_settings_screen.dart';
import '../controllers/label_reprint_controller.dart';
import '../controllers/label_reprint_state.dart';

/// Blocking dialog that drives the full reprint pipeline.
///
/// Caller is responsible for invoking
/// `LabelReprintController.reprint(generatedRollId)` once the dialog
/// has mounted (the dialog itself doesn't trigger work — the home
/// handler kicks the controller before / right after `showDialog`).
///
/// Dialog states (read from [LabelReprintController]):
///   - Fetching     → spinner + "جاري تجهيز الليبل…"
///   - Printing     → spinner + "جاري إرسال الليبل للطابعة…"
///   - Sent         → "تم إرسال الليبل للطابعة" + إغلاق
///   - FailureState → error + إعادة المحاولة / إعدادات الطباعة / إغلاق
///
/// Dismissal is blocked while Fetching or Printing
/// (`PopScope(canPop: false)`).
class PrintInProgressDialog extends ConsumerWidget {
  const PrintInProgressDialog({super.key, required this.shiftLineId});

  final int shiftLineId;

  // ─── Prescribed Arabic copy ─────────────────────────────────────────────
  static const String fetchingMessage = 'جاري تجهيز الليبل…';
  static const String printingMessage = 'جاري إرسال الليبل للطابعة…';
  static const String sentTitle = 'تم إرسال الليبل للطابعة';
  static const String sentDetail =
      'تأكد من خروج الليبل من الطابعة قبل الإغلاق.';
  static const String failureTitle = 'تعذّر إرسال الليبل';
  static const String retryLabel = 'إعادة المحاولة';
  static const String changePrinterLabel = 'إعدادات الطباعة';
  static const String closeLabel = 'إغلاق';

  /// Convenience entry-point for the home tap handler.
  static Future<void> show(BuildContext context, {required int shiftLineId}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext _) =>
          PrintInProgressDialog(shiftLineId: shiftLineId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LabelReprintState state = ref.watch(
      labelReprintControllerProvider(shiftLineId),
    );

    final bool blocking =
        state is LabelReprintFetching || state is LabelReprintPrinting;

    return PopScope(
      canPop: !blocking,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: switch (state) {
            LabelReprintFetching() => const _ProgressBody(
              message: fetchingMessage,
            ),
            LabelReprintPrinting() => const _ProgressBody(
              message: printingMessage,
            ),
            LabelReprintSent() => const _SuccessBody(),
            LabelReprintFailureState(:final message) => _FailureBody(
              message: message,
            ),
            // Idle / Ready shouldn't normally render in this dialog, but
            // fall back to a small spinner so a stray render isn't blank.
            _ => const _ProgressBody(message: fetchingMessage),
          },
          actions: switch (state) {
            LabelReprintSent() => <Widget>[
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: closeLabel,
                  icon: Icons.check_rounded,
                  onPressed: () {
                    ref
                        .read(
                          labelReprintControllerProvider(shiftLineId).notifier,
                        )
                        .cancel();
                    Navigator.of(context).maybePop();
                  },
                ),
              ),
            ],
            LabelReprintFailureState() => <Widget>[
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  label: retryLabel,
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref
                      .read(
                        labelReprintControllerProvider(shiftLineId).notifier,
                      )
                      .retry(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: AppSecondaryButton(
                  label: changePrinterLabel,
                  icon: Icons.print_rounded,
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const PrinterSettingsScreen(),
                      ),
                    );
                    // No state change here — the worker can press Retry
                    // after configuring a printer.
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    ref
                        .read(
                          labelReprintControllerProvider(shiftLineId).notifier,
                        )
                        .cancel();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text(closeLabel),
                ),
              ),
            ],
            _ => const <Widget>[],
          },
        ),
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: AppTextStyles.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SuccessBody extends StatelessWidget {
  const _SuccessBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 32,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          PrintInProgressDialog.sentTitle,
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          PrintInProgressDialog.sentDetail,
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          PrintInProgressDialog.failureTitle,
          style: AppTextStyles.h3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        InlineError(message: message),
      ],
    );
  }
}
