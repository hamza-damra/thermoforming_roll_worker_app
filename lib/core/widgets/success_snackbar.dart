import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Non-blocking success feedback (handoff §11 — Non-blocking success).
///
/// Use this for any "operation succeeded" surface that previously required
/// the worker to dismiss a dialog or tap an acknowledge button. Errors and
/// decision-required prompts stay as dialogs.
///
/// The snackbar dismisses any currently-visible snackbar first, so rapid
/// successive operations (close → close → close) never stack.
class SuccessSnackbar {
  SuccessSnackbar._();

  /// Default visible duration. Short enough to stay out of the way of the
  /// next scan/action, long enough to be read.
  static const Duration defaultDuration = Duration(milliseconds: 1800);

  /// Show a brief success snackbar with [message]. No-op when the context
  /// is no longer mounted.
  static void show(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppColors.textOnPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: duration ?? defaultDuration,
        ),
      );
  }
}
