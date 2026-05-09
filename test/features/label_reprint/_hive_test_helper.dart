import 'dart:io';

import 'package:hive/hive.dart';
import 'package:thermoforming_roll_worker/features/printer/data/models/label_preset_model.dart';
import 'package:thermoforming_roll_worker/features/printer/data/models/printer_config_model.dart';
import 'package:thermoforming_roll_worker/features/printer/data/models/printing_settings_model.dart';
import 'package:thermoforming_roll_worker/features/printer/data/printing_local_storage.dart';

/// Initializes Hive against a fresh temporary directory + opens the three
/// printer boxes the controller reads from, then pipes them into
/// `PrintingLocalStorage` via its `@visibleForTesting` seam. Returns the
/// temp path so the caller can clean it up in `tearDown`.
///
/// `LabelReprintController._print` reads `PrintingLocalStorage.getSettings()`
/// to resolve preset id and copies. The static `_settingsBox` field has to
/// be populated, otherwise the controller crashes with the Arabic
/// "not initialised" message.
Future<Directory> initHiveForTest() async {
  final Directory dir = await Directory.systemTemp.createTemp(
    'thermo_roll_worker_hive_test_',
  );
  Hive.init(dir.path);

  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(PrinterConfigModelAdapter());
  }
  if (!Hive.isAdapterRegistered(11)) {
    Hive.registerAdapter(LabelPresetModelAdapter());
  }
  if (!Hive.isAdapterRegistered(12)) {
    Hive.registerAdapter(PrintingSettingsModelAdapter());
  }

  final printers = await Hive.openBox<PrinterConfigModel>('printers');
  final presets = await Hive.openBox<LabelPresetModel>('custom_presets');
  final settings = await Hive.openBox<PrintingSettingsModel>(
    'printing_settings',
  );

  PrintingLocalStorage.initializeForTest(
    printers: printers,
    presets: presets,
    settings: settings,
  );

  return dir;
}

Future<void> closeHiveForTest(Directory dir) async {
  PrintingLocalStorage.resetForTest();
  await Hive.close();
  if (dir.existsSync()) {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {
      // Best-effort cleanup; Windows occasionally holds locks on lock
      // files. Tests still pass — the temp dir gets reclaimed by the OS.
    }
  }
}
