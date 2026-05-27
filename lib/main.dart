import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'features/printer/data/printing_local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Boot Hive boxes for the printer subsystem (saved printers, custom
  // label presets, last-selected preset/copies). One-time cost at app
  // start; safe to call multiple times.
  await PrintingLocalStorage.initialize();
  _logStartupConfig();
  runApp(const ProviderScope(child: RollWorkerApp()));
}

/// Emits a one-line, secret-free banner so QA can confirm which backend
/// the build is talking to. Device key, session tokens, and credentials
/// are never included.
void _logStartupConfig() {
  final AppConfig config = AppConfig.fromEnvironment();
  debugPrint(
    '[roll-worker] startup '
    'APP_ENV=${config.environment.name} '
    'baseUrl=${config.apiBaseUrl.isEmpty ? '<missing>' : config.apiBaseUrl} '
    'allowStagingSelfSignedCert=${config.allowStagingSelfSignedCert}',
  );
}
