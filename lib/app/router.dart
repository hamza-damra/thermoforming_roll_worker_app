import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/config/config_providers.dart';
import '../features/config_check/presentation/missing_config_screen.dart';
import 'bootstrap_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String missingConfig = '/missing-config';
  static const String bootstrap = '/';
}

/// Builds the app router. The redirect gate routes everything to
/// [MissingConfigScreen] whenever [AppConfig] is missing, so no other route
/// can issue a network call before the operator fixes the build config.
GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.bootstrap,
    redirect: (BuildContext context, GoRouterState state) {
      final AppConfig config = ref.read(appConfigProvider);
      final bool atGate = state.matchedLocation == AppRoutes.missingConfig;
      if (config.isMissing) {
        return atGate ? null : AppRoutes.missingConfig;
      }
      if (atGate) return AppRoutes.bootstrap;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.missingConfig,
        builder: (context, state) => const MissingConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.bootstrap,
        builder: (context, state) => const BootstrapScreen(),
      ),
    ],
  );
}
