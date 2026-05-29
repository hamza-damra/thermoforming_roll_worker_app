import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Non-blocking failure feedback — the error-colored counterpart to
/// [SuccessSnackbar]. Used for transient, recoverable failures (e.g. a
/// pull-to-refresh that could not reach the backend) where a blocking dialog
/// would be too heavy. Decision-required errors stay as dialogs.
///
/// Dismisses any currently-visible snackbar first so rapid retries never
/// stack, and is a no-op once the context is unmounted.
class FailureSnackbar {
  FailureSnackbar._();

  static const Duration defaultDuration = Duration(milliseconds: 2600);

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
                Icons.error_outline_rounded,
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
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: duration ?? defaultDuration,
        ),
      );
  }
}
