import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../printer/data/printer_providers.dart';
import '../../../printer/domain/entities/printer_config.dart';
import '../../../printer/presentation/screens/printer_settings_screen.dart';
import '../../domain/entities/roll_label.dart';
import '../controllers/label_reprint_controller.dart';
import '../controllers/label_reprint_state.dart';
import '../widgets/label_sticker_widget.dart';
import '../widgets/print_in_progress_dialog.dart';

/// Secondary, optional preview screen for the reprint flow.
///
/// The home reprint button fires physical printing immediately — this
/// screen is reachable via the small "معاينة الليبل" link as a way for
/// the worker to inspect the canonical sticker payload before deciding
/// to print, or as a fallback debug view.
///
/// The print button on this screen routes through the same blocking
/// [PrintInProgressDialog] used by the home flow, so there is exactly
/// one physical-print code path in the app.
class LabelPreviewScreen extends ConsumerStatefulWidget {
  const LabelPreviewScreen({
    super.key,
    required this.shiftLineId,
    required this.generatedRollId,
  });

  final int shiftLineId;
  final String generatedRollId;

  static const String title = 'معاينة الليبل';
  static const String reprintButtonLabel = 'إعادة طباعة الليبل';
  static const String fetchingMessage = 'جاري تجهيز الليبل…';
  static const String retry = 'إعادة المحاولة';

  @override
  ConsumerState<LabelPreviewScreen> createState() => _LabelPreviewScreenState();
}

class _LabelPreviewScreenState extends ConsumerState<LabelPreviewScreen> {
  bool _initialFetchKicked = false;

  void _ensureInitialFetch() {
    if (_initialFetchKicked) return;
    _initialFetchKicked = true;
    final LabelReprintState s = ref.read(
      labelReprintControllerProvider(widget.shiftLineId),
    );
    if (s is LabelReprintIdle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(labelReprintControllerProvider(widget.shiftLineId).notifier)
            .previewOnly(widget.generatedRollId);
      });
    }
  }

  Future<void> _onPrintTap(BuildContext context, RollLabel label) async {
    final PrinterConfig? printer = ref
        .read(printerRepositoryProvider)
        .getDefault();
    if (printer == null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const PrinterSettingsScreen()),
      );
      return;
    }
    final Future<void> dialog = PrintInProgressDialog.show(
      context,
      shiftLineId: widget.shiftLineId,
    );
    // ignore: unawaited_futures
    ref
        .read(labelReprintControllerProvider(widget.shiftLineId).notifier)
        .printAlreadyFetched();
    await dialog;
    // After dialog dismissal the controller is back at Idle (worker
    // closed it). Re-fetch the preview so the screen still shows
    // something useful if the worker stays here.
    if (!mounted) return;
    ref
        .read(labelReprintControllerProvider(widget.shiftLineId).notifier)
        .previewOnly(label.generatedRollId);
  }

  Future<void> _retryFetch() async {
    await ref
        .read(labelReprintControllerProvider(widget.shiftLineId).notifier)
        .previewOnly(widget.generatedRollId);
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialFetch();

    final LabelReprintState reprintState = ref.watch(
      labelReprintControllerProvider(widget.shiftLineId),
    );

    return AppScaffold(
      title: LabelPreviewScreen.title,
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _Body(reprintState: reprintState, onRetry: _retryFetch),
          const SizedBox(height: 16),
          if (reprintState is LabelReprintReady)
            AppPrimaryButton(
              label: LabelPreviewScreen.reprintButtonLabel,
              icon: Icons.print_rounded,
              onPressed: () => _onPrintTap(context, reprintState.label),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.reprintState, required this.onRetry});

  final LabelReprintState reprintState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (reprintState) {
      LabelReprintIdle() || LabelReprintFetching() || LabelReprintPrinting() =>
        const _LoadingPanel(message: LabelPreviewScreen.fetchingMessage),
      LabelReprintReady(:final label) ||
      LabelReprintSent(:final label) => LabelStickerWidget(label: label),
      LabelReprintFailureState(:final message) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InlineError(message: message),
              const SizedBox(height: 12),
              AppSecondaryButton(
                label: LabelPreviewScreen.retry,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    };
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.label),
          ],
        ),
      ),
    );
  }
}
