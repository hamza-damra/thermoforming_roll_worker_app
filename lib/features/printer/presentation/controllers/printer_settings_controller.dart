import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/printing_constants.dart';
import '../../data/printer_providers.dart';
import '../../data/printing_local_storage.dart';
import '../../domain/entities/label_preset.dart';
import '../../domain/entities/printer_config.dart';
import '../../pipeline/printer_client.dart';

/// Snapshot of printer-settings state for the screen. Read by the screen,
/// mutated through the controller's mutating methods.
@immutable
class PrinterSettingsSnapshot {
  const PrinterSettingsSnapshot({
    required this.printers,
    required this.presets,
    this.selectedPresetId,
    this.copies = PrintingConstants.defaultCopies,
  });

  final List<PrinterConfig> printers;
  final List<LabelPreset> presets;
  final String? selectedPresetId;
  final int copies;

  PrinterSettingsSnapshot copyWith({
    List<PrinterConfig>? printers,
    List<LabelPreset>? presets,
    String? selectedPresetId,
    int? copies,
  }) {
    return PrinterSettingsSnapshot(
      printers: printers ?? this.printers,
      presets: presets ?? this.presets,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      copies: copies ?? this.copies,
    );
  }
}

class PrinterSettingsController extends Notifier<PrinterSettingsSnapshot> {
  @override
  PrinterSettingsSnapshot build() {
    final settings = PrintingLocalStorage.getSettings();
    return PrinterSettingsSnapshot(
      printers: ref.read(printerRepositoryProvider).getAll(),
      presets: ref.read(presetRepositoryProvider).getAll(),
      selectedPresetId:
          settings.selectedPresetId ?? PrintingConstants.defaultPresetId,
      copies: settings.copies,
    );
  }

  Future<void> addPrinter(PrinterConfig printer) async {
    final List<PrinterConfig> existing = ref
        .read(printerRepositoryProvider)
        .getAll();
    final bool wantsDefault = existing.isEmpty || printer.isDefault;
    await ref
        .read(printerRepositoryProvider)
        .save(printer.copyWith(isDefault: wantsDefault));
    if (wantsDefault) {
      // Re-resolve the new id by reading back, then set as default.
      final List<PrinterConfig> all = ref
          .read(printerRepositoryProvider)
          .getAll();
      final PrinterConfig fresh = all.firstWhere(
        (PrinterConfig p) =>
            p.name == printer.name &&
            p.ip == printer.ip &&
            p.port == printer.port,
        orElse: () => all.last,
      );
      await ref.read(printerRepositoryProvider).setDefault(fresh.id);
    }
    state = state.copyWith(
      printers: ref.read(printerRepositoryProvider).getAll(),
    );
  }

  Future<void> updatePrinter(PrinterConfig printer) async {
    await ref.read(printerRepositoryProvider).save(printer);
    state = state.copyWith(
      printers: ref.read(printerRepositoryProvider).getAll(),
    );
  }

  Future<void> deletePrinter(String id) async {
    await ref.read(printerRepositoryProvider).delete(id);
    state = state.copyWith(
      printers: ref.read(printerRepositoryProvider).getAll(),
    );
  }

  Future<void> setDefault(String id) async {
    await ref.read(printerRepositoryProvider).setDefault(id);
    state = state.copyWith(
      printers: ref.read(printerRepositoryProvider).getAll(),
    );
  }

  Future<void> selectPreset(String presetId) async {
    final settings = PrintingLocalStorage.getSettings()
      ..selectedPresetId = presetId;
    await PrintingLocalStorage.saveSettings(settings);
    state = state.copyWith(selectedPresetId: presetId);
  }

  Future<void> setCopies(int count) async {
    final int clamped = count.clamp(1, 10);
    final settings = PrintingLocalStorage.getSettings()..copies = clamped;
    await PrintingLocalStorage.saveSettings(settings);
    state = state.copyWith(copies: clamped);
  }

  /// Probes the configured printer with a TCP connect (no print). Used by
  /// the add/edit dialogs.
  Future<bool> testConnection(PrinterConfig printer) =>
      PrinterClient(printer).testConnection();
}

final printerSettingsControllerProvider =
    NotifierProvider<PrinterSettingsController, PrinterSettingsSnapshot>(
      PrinterSettingsController.new,
    );
