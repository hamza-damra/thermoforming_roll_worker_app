import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/label_preset_model.dart';
import 'models/printer_config_model.dart';
import 'models/printing_settings_model.dart';

/// Boots the Hive boxes used by the printer feature. Adapted from
/// `roll_production_app`.
///
/// Three boxes / typeIds:
///   - 10: `PrinterConfigModel` in `"printers"`
///   - 11: `LabelPresetModel` in `"custom_presets"`
///   - 12: `PrintingSettingsModel` in `"printing_settings"`
///
/// Call `initialize()` exactly once at app start before the first frame.
class PrintingLocalStorage {
  PrintingLocalStorage._();

  static const String _printersBoxName = 'printers';
  static const String _presetsBoxName = 'custom_presets';
  static const String _settingsBoxName = 'printing_settings';
  static const String _settingsKey = 'settings';

  static Box<PrinterConfigModel>? _printersBox;
  static Box<LabelPresetModel>? _presetsBox;
  static Box<PrintingSettingsModel>? _settingsBox;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(PrinterConfigModelAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(LabelPresetModelAdapter());
    }
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(PrintingSettingsModelAdapter());
    }

    _printersBox = await Hive.openBox<PrinterConfigModel>(_printersBoxName);
    _presetsBox = await Hive.openBox<LabelPresetModel>(_presetsBoxName);
    _settingsBox = await Hive.openBox<PrintingSettingsModel>(_settingsBoxName);

    _initialized = true;
  }

  static Box<PrinterConfigModel> get printersBox =>
      _requireInitialized(_printersBox);
  static Box<LabelPresetModel> get presetsBox =>
      _requireInitialized(_presetsBox);
  static Box<PrintingSettingsModel> get settingsBox =>
      _requireInitialized(_settingsBox);

  static PrintingSettingsModel getSettings() {
    return settingsBox.get(_settingsKey) ?? PrintingSettingsModel();
  }

  static Future<void> saveSettings(PrintingSettingsModel settings) {
    return settingsBox.put(_settingsKey, settings);
  }

  static Future<void> close() async {
    await _printersBox?.close();
    await _presetsBox?.close();
    await _settingsBox?.close();
    _printersBox = null;
    _presetsBox = null;
    _settingsBox = null;
    _initialized = false;
  }

  /// Test-only seam. The controller (`LabelReprintController._print`) reads
  /// `getSettings()`, which routes through the private static box. Tests
  /// open boxes against a temp dir via `Hive.openBox(...)` and pipe them
  /// in here so the static getters resolve without touching `Hive.initFlutter()`.
  @visibleForTesting
  static void initializeForTest({
    required Box<PrinterConfigModel> printers,
    required Box<LabelPresetModel> presets,
    required Box<PrintingSettingsModel> settings,
  }) {
    _printersBox = printers;
    _presetsBox = presets;
    _settingsBox = settings;
    _initialized = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _printersBox = null;
    _presetsBox = null;
    _settingsBox = null;
    _initialized = false;
  }

  static Box<T> _requireInitialized<T>(Box<T>? box) {
    if (box == null) {
      throw StateError(
        'لم يتم تهيئة التخزين المحلي للطباعة. يرجى استدعاء initialize() أولاً.',
      );
    }
    return box;
  }
}
