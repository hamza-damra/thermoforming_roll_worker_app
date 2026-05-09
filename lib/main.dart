import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/printer/data/printing_local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Boot Hive boxes for the printer subsystem (saved printers, custom
  // label presets, last-selected preset/copies). One-time cost at app
  // start; safe to call multiple times.
  await PrintingLocalStorage.initialize();
  runApp(const ProviderScope(child: RollWorkerApp()));
}
