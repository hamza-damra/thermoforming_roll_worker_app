import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Shimmer skeleton primitives — used only for **true first-load** placeholders.
///
/// Background refreshes must keep the previous data visible (no shimmer) so
/// the app never flickers on resume. Only emit shimmer when the state is
/// genuinely empty (e.g., `SummaryLoading` / `SessionsMeLoading` on cold
/// open or after a logout/login).
class AppShimmerSkeleton {
  AppShimmerSkeleton._();

  /// Wrap any child in the project's shimmer gradient. Prefer the smaller
  /// primitive widgets below for typical placeholder layouts.
  ///
  /// [accent] tints the base color toward the active line color (orange /
  /// green / blue …) so the skeleton matches the themed dashboard it stands
  /// in for; `null` falls back to the neutral brand tint. The sweep runs
  /// right-to-left to respect the app's RTL layout.
  static Widget wrap({required Widget child, Color? accent}) {
    return Shimmer.fromColors(
      baseColor: accent == null
          ? AppColors.primaryLight
          : Color.alphaBlend(
              accent.withValues(alpha: 0.16),
              const Color(0xFFECECEC),
            ),
      highlightColor: AppColors.surface,
      period: const Duration(milliseconds: 1400),
      direction: ShimmerDirection.rtl,
      child: child,
    );
  }
}

/// A grey rectangle of [width] × [height] used inside [AppShimmerSkeleton.wrap].
class AppShimmerBlock extends StatelessWidget {
  const AppShimmerBlock({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 6,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A line-shaped shimmer block (rounded ends, fixed thickness).
class AppShimmerLine extends StatelessWidget {
  const AppShimmerLine({
    super.key,
    this.width = double.infinity,
    this.height = 12,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppShimmerBlock(
      width: width,
      height: height,
      borderRadius: height / 2,
    );
  }
}
