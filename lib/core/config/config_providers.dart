import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Resolves [AppConfig] once at app start; treat as immutable.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
