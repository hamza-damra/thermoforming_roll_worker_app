import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/info_row.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../roll_worker_auth/presentation/controllers/batch_auth_controller.dart';
import '../../../roll_worker_auth/presentation/controllers/batch_auth_state.dart';
import '../../../roll_worker_auth/presentation/screens/pin_screen.dart';
import '../../domain/entities/active_shift_line_option.dart';
import '../controllers/active_shift_line_options_controller.dart';
import '../controllers/active_shift_line_options_state.dart';
import '../controllers/selected_shift_line_provider.dart';
import '../widgets/conflict_badge.dart';

/// Pre-login picker for currently-ACTIVE Thermoforming shift-lines.
///
/// Multi-select: the worker may tick 1..N lines and proceed with a single
/// PIN entry against the multi-line batch session-start endpoint. After a
/// per-line conflict, the offending id is dropped from the selection and
/// the row briefly highlighted so the worker can adjust and retry.
class ActiveShiftLinePickerScreen extends ConsumerStatefulWidget {
  const ActiveShiftLinePickerScreen({super.key});

  static const String title = 'تطبيق عامل الرولات';
  static const String headerTitle = 'اختر خطوط التشكيل';
  static const String headerHint = 'يمكنك اختيار خط واحد أو أكثر';

  // Empty-state copy.
  static const String emptyHeadline = 'بانتظار فتح خط من تطبيق المشغّل';
  static const String emptyDetail =
      'سيظهر الخط هنا فور فتحه من تطبيق المشغّل. اسحب للأسفل للتحديث.';
  static const String retryLabel = 'إعادة المحاولة';

  // Card labels.
  static const String thermoformingLineLabel = 'خط التشكيل';
  static const String palletizingLineLabel = 'خط الطبليات المرتبط';
  static const String currentProductLabel = 'المنتج الحالي';
  static const String operatorLabel = 'المشغّل';
  static const String currentRollHeading = 'الرول الحالي';
  static const String rollIdLabel = 'رقم الرول';
  static const String rollTypeLabel = 'نوع الرول';
  static const String currentWeightLabel = 'الوزن الحالي';
  static const String missingValue = '—';

  // CTA copy (handoff §5.1).
  static const String ctaEmpty = 'اختر على الأقل خطاً واحداً';
  static const String ctaSingle = 'متابعة';
  static String ctaMultiple(int n) => 'متابعة بـ $n خطوط';

  // Conflict toast.
  static const String conflictDropToast = 'خط غير متاح، تم استبعاده';

  static String _formatWeight(double? kg) {
    if (kg == null) return missingValue;
    final String trimmed = kg
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$trimmed kg';
  }

  @override
  ConsumerState<ActiveShiftLinePickerScreen> createState() =>
      _ActiveShiftLinePickerScreenState();
}

class _ActiveShiftLinePickerScreenState
    extends ConsumerState<ActiveShiftLinePickerScreen> {
  /// Ids that just came back as conflicts from a batch-start failure. Used
  /// for a transient row highlight; cleared on the next selection toggle
  /// or refresh.
  Set<int> _justConflicted = const <int>{};

  void _onToggle(int shiftLineId) {
    if (_justConflicted.isNotEmpty) {
      setState(() => _justConflicted = const <int>{});
    }
    ref.read(pickerShiftLineSelectionProvider.notifier).toggle(shiftLineId);
  }

  Future<void> _onRefresh() async {
    setState(() => _justConflicted = const <int>{});
    await ref
        .read(activeShiftLineOptionsControllerProvider.notifier)
        .refresh();
  }

  Future<void> _onContinue() async {
    final Set<int> selection = ref.read(pickerShiftLineSelectionProvider);
    if (selection.isEmpty) return;
    // Reset any stale failure before re-entering the PIN screen so a prior
    // OPERATOR_PIN_INVALID inline error doesn't pre-flash.
    ref.read(batchAuthControllerProvider.notifier).reset();

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PinScreen(shiftLineIds: selection),
      ),
    );
    if (!mounted) return;

    // After PIN screen pops, inspect the latest BatchAuthFailure for any
    // per-line conflict ids; drop them from the selection and surface the
    // toast so the worker can retry with the surviving subset.
    final BatchAuthState authState = ref.read(batchAuthControllerProvider);
    if (authState is BatchAuthFailure &&
        authState.conflictShiftLineIds != null &&
        authState.conflictShiftLineIds!.isNotEmpty) {
      final Set<int> conflicts = authState.conflictShiftLineIds!;
      ref
          .read(pickerShiftLineSelectionProvider.notifier)
          .replaceWith(
            ref
                .read(pickerShiftLineSelectionProvider)
                .difference(conflicts),
          );
      // Refresh the active-options so any newly-disappeared row updates.
      // ignore: unawaited_futures
      ref
          .read(activeShiftLineOptionsControllerProvider.notifier)
          .refresh();
      setState(() => _justConflicted = conflicts);
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(ActiveShiftLinePickerScreen.conflictDropToast),
            duration: Duration(seconds: 3),
          ),
        );
      ref.read(batchAuthControllerProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ActiveShiftLineOptionsState state = ref.watch(
      activeShiftLineOptionsControllerProvider,
    );
    final Set<int> selection = ref.watch(pickerShiftLineSelectionProvider);

    return AppScaffold(
      title: ActiveShiftLinePickerScreen.title,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: _buildBody(context, state, selection),
      ),
      bottomBar: _ContinueBar(
        selectionCount: selection.length,
        onContinue: selection.isEmpty ? null : _onContinue,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ActiveShiftLineOptionsState state,
    Set<int> selection,
  ) {
    return switch (state) {
      ActiveShiftLineOptionsInitial() => const _LoadingView(),
      ActiveShiftLineOptionsLoading(:final previous) => previous.isEmpty
          ? const _LoadingView()
          : _OptionsListView(
              options: previous,
              selection: selection,
              conflictedIds: _justConflicted,
              onToggle: _onToggle,
              showRefreshingHeader: true,
            ),
      ActiveShiftLineOptionsLoaded(:final options) => options.isEmpty
          ? const _EmptyView()
          : _OptionsListView(
              options: options,
              selection: selection,
              conflictedIds: _justConflicted,
              onToggle: _onToggle,
              showRefreshingHeader: false,
            ),
      ActiveShiftLineOptionsFailureState(:final failure, :final previous) =>
        _FailureView(
          failure: arabicMessageFor(failure),
          previous: previous,
          selection: selection,
          conflictedIds: _justConflicted,
          onRetry: _onRefresh,
          onToggle: _onToggle,
        ),
    };
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.selectionCount, required this.onContinue});

  final int selectionCount;
  final VoidCallback? onContinue;

  String get _label {
    if (selectionCount == 0) return ActiveShiftLinePickerScreen.ctaEmpty;
    if (selectionCount == 1) return ActiveShiftLinePickerScreen.ctaSingle;
    return ActiveShiftLinePickerScreen.ctaMultiple(selectionCount);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: AppPrimaryButton(
          label: _label,
          icon: Icons.check_circle_outline_rounded,
          onPressed: onContinue,
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          ActiveShiftLinePickerScreen.emptyHeadline,
          style: AppTextStyles.h2,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            ActiveShiftLinePickerScreen.emptyDetail,
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        Consumer(
          builder: (context, ref, _) {
            return AppSecondaryButton(
              label: ActiveShiftLinePickerScreen.retryLabel,
              icon: Icons.refresh_rounded,
              onPressed: () => ref
                  .read(activeShiftLineOptionsControllerProvider.notifier)
                  .refresh(),
            );
          },
        ),
      ],
    );
  }
}

class _OptionsListView extends StatelessWidget {
  const _OptionsListView({
    required this.options,
    required this.selection,
    required this.conflictedIds,
    required this.onToggle,
    required this.showRefreshingHeader,
  });

  final List<ActiveShiftLineOption> options;
  final Set<int> selection;
  final Set<int> conflictedIds;
  final ValueChanged<int> onToggle;
  final bool showRefreshingHeader;

  @override
  Widget build(BuildContext context) {
    final int leadingCount = (showRefreshingHeader ? 1 : 0) + 1; // header
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: options.length + leadingCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return const _PickerHeader();
        if (showRefreshingHeader && index == 1) {
          return const _RefreshingHeader();
        }
        final ActiveShiftLineOption option = options[index - leadingCount];
        return _ShiftLineCard(
          option: option,
          selected: selection.contains(option.shiftLineId),
          conflicted: conflictedIds.contains(option.shiftLineId),
          onToggle: onToggle,
        );
      },
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          ActiveShiftLinePickerScreen.headerTitle,
          style: AppTextStyles.h2,
        ),
        SizedBox(height: 4),
        Text(
          ActiveShiftLinePickerScreen.headerHint,
          style: AppTextStyles.label,
        ),
      ],
    );
  }
}

class _RefreshingHeader extends StatelessWidget {
  const _RefreshingHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        SizedBox(width: 8),
        Text('جارٍ التحديث…', style: AppTextStyles.label),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.failure,
    required this.previous,
    required this.selection,
    required this.conflictedIds,
    required this.onRetry,
    required this.onToggle,
  });

  final String failure;
  final List<ActiveShiftLineOption> previous;
  final Set<int> selection;
  final Set<int> conflictedIds;
  final VoidCallback onRetry;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 12),
        InlineError(message: failure),
        const SizedBox(height: 12),
        AppSecondaryButton(
          label: ActiveShiftLinePickerScreen.retryLabel,
          icon: Icons.refresh_rounded,
          onPressed: onRetry,
        ),
        if (previous.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final ActiveShiftLineOption option in previous) ...[
            _ShiftLineCard(
              option: option,
              selected: selection.contains(option.shiftLineId),
              conflicted: conflictedIds.contains(option.shiftLineId),
              onToggle: onToggle,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _ShiftLineCard extends StatelessWidget {
  const _ShiftLineCard({
    required this.option,
    required this.selected,
    required this.conflicted,
    required this.onToggle,
  });

  final ActiveShiftLineOption option;
  final bool selected;
  final bool conflicted;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final String thermoLine =
        '${option.thermoformingLineName} (${option.thermoformingLineCode})';
    final String palletizingLine =
        '${option.palletizingLineName} (${option.palletizingLineCode})';
    final String product =
        option.currentProductTypeName ??
        ActiveShiftLinePickerScreen.missingValue;
    final String operator =
        option.operatorName ?? ActiveShiftLinePickerScreen.missingValue;

    final BoxBorder? border = conflicted
        ? Border.all(color: AppColors.warning, width: 2)
        : null;

    return InkWell(
      onTap: option.selectable ? () => onToggle(option.shiftLineId) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: border == null
            ? null
            : BoxDecoration(
                border: border,
                borderRadius: BorderRadius.circular(12),
              ),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: option.selectable
                        ? (_) => onToggle(option.shiftLineId)
                        : null,
                  ),
                  Expanded(
                    child: Text(thermoLine, style: AppTextStyles.h3),
                  ),
                ],
              ),
              if (option.hasOtherActiveOperator) ...[
                const SizedBox(height: 4),
                ConflictBadge(
                  operatorName: option.existingSessionOperatorName ?? '',
                ),
              ],
              const SizedBox(height: 8),
              InfoRow(
                label: ActiveShiftLinePickerScreen.palletizingLineLabel,
                value: palletizingLine,
                icon: Icons.local_shipping_rounded,
              ),
              InfoRow(
                label: ActiveShiftLinePickerScreen.currentProductLabel,
                value: product,
                icon: Icons.category_rounded,
              ),
              InfoRow(
                label: ActiveShiftLinePickerScreen.operatorLabel,
                value: operator,
                icon: Icons.person_rounded,
              ),
              if (option.hasMountedRoll) ...[
                const Divider(height: 24),
                const Text(
                  ActiveShiftLinePickerScreen.currentRollHeading,
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 4),
                InfoRow(
                  label: ActiveShiftLinePickerScreen.rollIdLabel,
                  value:
                      option.currentRollGeneratedRollId ??
                      ActiveShiftLinePickerScreen.missingValue,
                  icon: Icons.qr_code_rounded,
                ),
                InfoRow(
                  label: ActiveShiftLinePickerScreen.rollTypeLabel,
                  value:
                      option.currentRollTypeName ??
                      option.currentRollTypeCode ??
                      ActiveShiftLinePickerScreen.missingValue,
                  icon: Icons.label_outline_rounded,
                ),
                InfoRow(
                  label: ActiveShiftLinePickerScreen.currentWeightLabel,
                  value: ActiveShiftLinePickerScreen._formatWeight(
                    option.currentRollLastKnownWeightKg,
                  ),
                  icon: Icons.scale_rounded,
                ),
              ],
              if (!option.selectable &&
                  option.blockingReason != null &&
                  option.blockingReason!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  option.blockingReason!,
                  style: AppTextStyles.label,
                  textAlign: TextAlign.start,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
