import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/config/config_providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/app_scaffold.dart';
import '../core/widgets/empty_state_view.dart';
import '../core/widgets/info_row.dart';
import '../features/config_check/presentation/missing_config_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String missingConfig = '/missing-config';
  static const String smoke = '/';
}

/// Builds the app router. The redirect gate routes everything to
/// [MissingConfigScreen] whenever [AppConfig] is missing, so no other route
/// can issue a network call before the operator fixes the build config.
GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.smoke,
    redirect: (BuildContext context, GoRouterState state) {
      final AppConfig config = ref.read(appConfigProvider);
      final bool atGate = state.matchedLocation == AppRoutes.missingConfig;
      if (config.isMissing) {
        return atGate ? null : AppRoutes.missingConfig;
      }
      // Config OK — keep users out of the gate screen.
      if (atGate) return AppRoutes.smoke;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.missingConfig,
        builder: (context, state) => const MissingConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.smoke,
        builder: (context, state) => const _SmokeHomeScreen(),
      ),
    ],
  );
}

/// Stage 1 smoke screen — confirms theme + RTL render correctly.
/// Will be replaced by the real waiting/PIN/home screens in later stages.
class _SmokeHomeScreen extends StatelessWidget {
  const _SmokeHomeScreen();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تطبيق عامل الرولات',
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('بيئة العمل', style: AppTextStyles.h2),
                SizedBox(height: 8),
                Text(
                  'الواجهة قيد التهيئة. ستتوفر شاشات تسجيل الدخول وعمليات الرولات في المراحل التالية.',
                  style: AppTextStyles.body,
                ),
                Divider(height: 24),
                InfoRow(
                  label: 'حالة التطبيق',
                  value: 'المرحلة الثانية — البنية الأساسية',
                  icon: Icons.settings_rounded,
                ),
                InfoRow(
                  label: 'اللغة',
                  value: 'العربية (RTL)',
                  icon: Icons.translate_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const EmptyStateView(
            icon: Icons.access_time_rounded,
            message:
                'بانتظار فتح خط من تطبيق المشغّل\n(سيتم تفعيل هذه الشاشة في المرحلة الرابعة)',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'هذه شاشة فحص أولي للتأكد من عمل التصميم العربي والتخطيط من اليمين لليسار.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
