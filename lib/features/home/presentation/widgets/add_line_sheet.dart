import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_messages_ar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_secondary_button.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../roll_worker_auth/presentation/screens/pin_screen.dart';
import '../../../sessions_me/data/sessions_me_providers.dart';
import '../../../sessions_me/domain/sessions_me_repository.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry.dart';
import '../../../roll_worker_auth/presentation/controllers/multi_line_session_registry_state.dart';
import '../../../shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import '../../../shift_line/presentation/widgets/shift_line_card.dart';

/// In-session "add another line" bottom sheet.
///
/// Fetches `/sessions/me/joinable-lines` (handoff §2.3 / §5.2 — the
/// backend already excludes lines the worker holds), renders the same
/// [ShiftLineCard] rows as the pre-login picker, lets the worker pick
/// 1..N selectable lines, then routes to the existing [PinScreen] with
/// the selected ids. `BatchAuthController.submit` handles the actual
/// `POST /sessions/start-batch` call (handoff §5.2 step 5).
///
/// The sheet pops itself the moment the user navigates to the PIN screen;
/// the merged registry then triggers `MultiLineHomeShell` to append the
/// new pages.
class AddLineSheet extends ConsumerStatefulWidget {
  const AddLineSheet({super.key});

  static const String title = 'إضافة خط آخر';
  static const String continueLabel = 'متابعة';
  static String continueWithCount(int n) => 'متابعة بـ $n خطوط';
  static const String continueSingle = 'متابعة بخط واحد';
  static const String emptyHeadline = 'لا توجد خطوط متاحة للإضافة';
  static const String emptyDetail =
      'كل الخطوط النشطة مرتبطة بالفعل بحسابك، أو لا يوجد خط آخر مفتوح حالياً.';
  static const String retryLabel = 'إعادة المحاولة';

  /// Convenience launcher — shows the sheet using the project's standard
  /// modal-bottom-sheet conventions.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddLineSheet(),
    );
  }

  @override
  ConsumerState<AddLineSheet> createState() => _AddLineSheetState();
}

class _AddLineSheetState extends ConsumerState<AddLineSheet> {
  Future<JoinableLinesResult>? _future;
  final Set<int> _selection = <int>{};

  @override
  void initState() {
    super.initState();
    _future = ref.read(sessionsMeRepositoryProvider).fetchJoinableLines();
  }

  void _onToggle(int shiftLineId) {
    setState(() {
      if (!_selection.add(shiftLineId)) {
        _selection.remove(shiftLineId);
      }
    });
  }

  void _onRefresh() {
    setState(() {
      _selection.clear();
      _future = ref.read(sessionsMeRepositoryProvider).fetchJoinableLines();
    });
  }

  Future<void> _onContinue() async {
    if (_selection.isEmpty) return;
    final NavigatorState navigator = Navigator.of(context);
    // Close the sheet BEFORE pushing the PIN screen so the user lands
    // straight on it (otherwise the sheet would still cover part of the
    // PIN screen until the user manually dismissed).
    navigator.pop();
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PinScreen(shiftLineIds: <int>{..._selection}),
      ),
    );
  }

  String _continueLabel() {
    if (_selection.isEmpty) return AddLineSheet.continueLabel;
    if (_selection.length == 1) return AddLineSheet.continueSingle;
    return AddLineSheet.continueWithCount(_selection.length);
  }

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(AddLineSheet.title, style: AppTextStyles.h2),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AppPrimaryButton(
                label: _continueLabel(),
                icon: Icons.arrow_forward_rounded,
                onPressed: _selection.isEmpty ? null : _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<JoinableLinesResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final JoinableLinesResult? result = snapshot.data;
        if (result == null) {
          return _ErrorBlock(
            message: genericRetryArabic,
            onRetry: _onRefresh,
          );
        }
        switch (result) {
          case JoinableLinesFailure(:final failure):
            return _ErrorBlock(
              message: arabicMessageFor(failure),
              onRetry: _onRefresh,
            );
          case JoinableLinesSuccess(:final lines):
            if (lines.isEmpty) {
              return const _EmptyBlock();
            }
            return _ListBody(
              lines: lines,
              selection: _selection,
              onToggle: _onToggle,
            );
        }
      },
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.lines,
    required this.selection,
    required this.onToggle,
  });

  final List<RollWorkerBootstrapLine> lines;
  final Set<int> selection;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: lines.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final RollWorkerBootstrapLine line = lines[index];
        return Consumer(
          builder: (context, ref, _) {
            final bool owned = ref.watch(
              multiLineSessionRegistryProvider.select(
                (s) =>
                    s is RegistryActive &&
                    line.shiftLineId != null &&
                    s.sessions.containsKey(line.shiftLineId),
              ),
            );
            return ShiftLineCard(
              key: ValueKey<int>(line.thermoformingLineId),
              line: line,
              selected: line.shiftLineId != null &&
                  selection.contains(line.shiftLineId),
              conflicted: false,
              onToggle: onToggle,
              ownedByMe: owned,
            );
          },
        );
      },
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.factory_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            AddLineSheet.emptyHeadline,
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            AddLineSheet.emptyDetail,
            style: AppTextStyles.label,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineError(message: message),
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: AddLineSheet.retryLabel,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
