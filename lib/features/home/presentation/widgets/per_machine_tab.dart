import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/primary_bottom_action.dart';
import '../../../roll_worker_auth/presentation/widgets/roll_worker_auth_overlay.dart';
import '../../../shift_line/domain/entities/roll_worker_bootstrap_line.dart';
import '../../../shift_line/presentation/controllers/roll_worker_bootstrap_controller.dart';
import '../screens/roll_worker_home_screen.dart';
import 'machine_dashboard_preview.dart';
import 'machine_waiting_card.dart';

/// Which of the three per-machine states this tab is in.
enum MachineTabKind { authorized, needsAuth, waiting }

/// One machine tab in the unified dashboard shell.
///
/// Kept alive across tab switches (so the live dashboard's scroll position,
/// listeners, and any pushed scan screen survive) and renders one of three
/// states in a `Stack`:
///   * [MachineTabKind.authorized] → the live [RollWorkerHomeScreen] body.
///   * [MachineTabKind.needsAuth]  → dimmed preview + blocking PIN overlay.
///   * [MachineTabKind.waiting]    → dimmed preview + blocking waiting card.
class PerMachineTab extends ConsumerStatefulWidget {
  const PerMachineTab({
    super.key,
    required this.kind,
    required this.shiftLineId,
    required this.lineIndex,
    required this.accent,
    required this.line,
    this.lineLabel,
    this.showLineHeader = false,
    this.waitingTitle = '',
    this.waitingMessage = '',
    this.waitingShowSpinner = true,
  });

  final MachineTabKind kind;

  /// Non-null for [MachineTabKind.authorized] and [MachineTabKind.needsAuth].
  final int? shiftLineId;
  final int lineIndex;

  /// Backend-derived line label (`خط أ`, `خط ب`, …) for the in-dashboard
  /// header. Falls back to the line index when absent.
  final String? lineLabel;

  /// Forwarded to the dashboard: show the in-body line header only when the
  /// shell's tab bar is hidden (single active line), so the label is never
  /// duplicated beside the tabs.
  final bool showLineHeader;
  final Color accent;

  /// `/bootstrap` row used to render the preview / waiting copy. May be null
  /// for a registry-only authorized session that no longer has a bootstrap
  /// row (then [kind] is always [MachineTabKind.authorized]).
  final RollWorkerBootstrapLine? line;

  final String waitingTitle;
  final String waitingMessage;
  final bool waitingShowSpinner;

  @override
  ConsumerState<PerMachineTab> createState() => _PerMachineTabState();
}

class _PerMachineTabState extends ConsumerState<PerMachineTab>
    with AutomaticKeepAliveClientMixin<PerMachineTab> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    switch (widget.kind) {
      case MachineTabKind.authorized:
        return RollWorkerHomeScreen(
          shiftLineId: widget.shiftLineId!,
          lineIndex: widget.lineIndex,
          lineLabel: widget.lineLabel,
          showLineHeader: widget.showLineHeader,
          standaloneScaffold: false,
          accentColor: widget.accent,
        );
      case MachineTabKind.needsAuth:
        return Stack(
          children: <Widget>[
            _backdrop(),
            Positioned.fill(
              child: RollWorkerAuthOverlay(
                shiftLineId: widget.shiftLineId!,
                accentColor: widget.accent,
              ),
            ),
          ],
        );
      case MachineTabKind.waiting:
        return Stack(
          children: <Widget>[
            _backdrop(),
            Positioned.fill(
              child: MachineWaitingCard(
                title: widget.waitingTitle,
                message: widget.waitingMessage,
                showWaitingRow: widget.waitingShowSpinner,
                onRefresh: () => ref
                    .read(rollWorkerBootstrapControllerProvider.notifier)
                    .refresh(trigger: 'waiting-refresh', background: true),
              ),
            ),
          ],
        );
    }
  }

  /// The dashboard backdrop shown behind a blocking overlay: the read-only
  /// machine preview plus the disabled primary scan action, so the screen
  /// reads as the real (dimmed/disabled) dashboard — never a login card.
  Widget _backdrop() {
    final RollWorkerBootstrapLine? line = widget.line;
    return Column(
      children: <Widget>[
        Expanded(
          child: line == null
              ? const SizedBox.expand()
              : MachineDashboardPreview(line: line, accent: widget.accent),
        ),
        const PrimaryBottomAction(
          label: RollWorkerHomeScreen.registerRoll,
          icon: Icons.qr_code_scanner_rounded,
          onPressed: null,
        ),
      ],
    );
  }
}
