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
  static Widget wrap({required Widget child}) {
    return Shimmer.fromColors(
      baseColor: AppColors.primaryLight,
      highlightColor: AppColors.surface,
      period: const Duration(milliseconds: 1400),
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
