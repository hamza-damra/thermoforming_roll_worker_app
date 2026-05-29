import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_shimmer_skeleton.dart';

/// First-load skeletons for the Roll Worker dashboard.
///
/// Two entry points, both driven purely by real provider state (no artificial
/// delay) and only shown on a genuine cold fetch — background refreshes keep
/// the previous data visible so the resume path never collapses to shimmer:
///
///   * [HomeShimmerSkeleton] — the per-line card stack (operator → roll
///     worker → product/allowed → mount). Rendered inside the live shell's
///     list while a line's `ShiftLineSummaryController` is in `SummaryLoading`
///     with no previous data.
///   * [RollWorkerLoadingScaffold] — the whole-screen skeleton (themed app
///     bar + tab placeholders + the card stack + a scan-button footer). Stands
///     in for the old green spinner during bootstrap / registry restore.
///
/// Every placeholder mirrors the size and chrome of the real widget it
/// replaces, so there is no layout jump when real data arrives. Each accepts
/// an [accent] so the skeleton carries the active line color.
class HomeShimmerSkeleton extends StatelessWidget {
  const HomeShimmerSkeleton({super.key, this.accent});

  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    return AppShimmerSkeleton.wrap(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Operator on duty.
          _SkeletonIdentityCard(accent: color),
          const SizedBox(height: 10),
          // Roll employee (+ leave action placeholder).
          _SkeletonIdentityCard(accent: color, trailingAction: true),
          const SizedBox(height: 10),
          // Current product + allowed-roll preview.
          _SkeletonProductCard(accent: color),
          const SizedBox(height: 10),
          // Mounted / empty roll state.
          _SkeletonMountCard(accent: color),
        ],
      ),
    );
  }
}

/// Whole-screen dashboard skeleton — replaces the legacy green-app-bar +
/// centered `CircularProgressIndicator` loading state. It is its own
/// [Scaffold] (themed app bar, tab placeholders, scan-button footer) so it can
/// be returned directly from the bootstrap / no-machines loading branches.
class RollWorkerLoadingScaffold extends StatelessWidget {
  const RollWorkerLoadingScaffold({super.key, this.accent});

  final Color? accent;

  // Kept in sync with RollWorkerHomeScreen.title — duplicated here only to
  // avoid a screen→widget import cycle for a single constant string.
  static const String _title = 'تطبيق موظف الرولات';

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? AppColors.primary;
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        backgroundColor: color,
        title: const Text(_title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: AppShimmerSkeleton.wrap(
              accent: color,
              child: const Row(
                children: <Widget>[
                  Expanded(child: Center(child: AppShimmerLine(width: 72))),
                  Expanded(child: Center(child: AppShimmerLine(width: 72))),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: <Widget>[HomeShimmerSkeleton(accent: color)],
            ),
          ),
          _SkeletonScanFooter(accent: color),
        ],
      ),
    );
  }
}

/// Mimics the operator / roll-worker identity cards: a header row (icon chip +
/// title line) and a full-width value pill. [trailingAction] adds a small
/// block standing in for the inline "leave" button.
class _SkeletonIdentityCard extends StatelessWidget {
  const _SkeletonIdentityCard({
    required this.accent,
    this.trailingAction = false,
  });

  final Color accent;
  final bool trailingAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      accent: accent,
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SkeletonHeaderRow(),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Expanded(child: AppShimmerLine(width: 160, height: 16)),
              if (trailingAction) ...<Widget>[
                const SizedBox(width: 12),
                const AppShimmerBlock(width: 96, height: 34, borderRadius: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Mimics the expandable product + allowed-rolls card: header, product name
/// line, and one full-width allowed-roll preview badge.
class _SkeletonProductCard extends StatelessWidget {
  const _SkeletonProductCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      accent: accent,
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SkeletonHeaderRow(),
          SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppShimmerLine(width: 180, height: 20),
          ),
          SizedBox(height: 12),
          AppShimmerBlock(width: double.infinity, height: 44, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Mimics the empty / mounted roll card.
class _SkeletonMountCard extends StatelessWidget {
  const _SkeletonMountCard({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: true,
      accent: accent,
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: const Row(
        children: <Widget>[
          AppShimmerBlock(width: 40, height: 40, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppShimmerLine(width: 180, height: 14),
                SizedBox(height: 8),
                AppShimmerLine(width: 110, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header row shared by the skeleton cards: an icon-chip block at the start
/// (right in RTL) with a title line beside it — mirrors [SectionHeader].
class _SkeletonHeaderRow extends StatelessWidget {
  const _SkeletonHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        AppShimmerBlock(width: 34, height: 34, borderRadius: 10),
        SizedBox(width: 10),
        AppShimmerLine(width: 130, height: 14),
      ],
    );
  }
}

/// Mimics the fixed bottom scan action (white footer + shadow + full-width
/// button placeholder).
class _SkeletonScanFooter extends StatelessWidget {
  const _SkeletonScanFooter({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: AppShimmerSkeleton.wrap(
            accent: accent,
            child: const AppShimmerBlock(
              width: double.infinity,
              height: 54,
              borderRadius: 12,
            ),
          ),
        ),
      ),
    );
  }
}
