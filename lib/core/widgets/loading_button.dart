import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Centered indeterminate spinner used for inline loading inside cards / dialogs.
class CenteredLoader extends StatelessWidget {
  const CenteredLoader({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: size,
        width: size,
        child: const CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}
