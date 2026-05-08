import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key, required this.online});

  final bool online;

  static const String offlineMessage =
      'لا يوجد اتصال بالخادم، سيتم إعادة المحاولة تلقائيًا';

  @override
  Widget build(BuildContext context) {
    if (online) return const SizedBox.shrink();
    return Material(
      color: AppColors.offlineBg,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.offline),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  offlineMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.offline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
