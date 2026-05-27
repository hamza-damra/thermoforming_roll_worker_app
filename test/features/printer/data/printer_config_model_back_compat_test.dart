import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:thermoforming_roll_worker/features/printer/data/models/printer_config_model.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/printer_language.dart';

/// Verifies that a `PrinterConfigModel` Hive record written under the
/// pre-multi-protocol schema (6 fields: 0..5) deserialises correctly with
/// the new 7-field adapter, with the missing `language` field resolving
/// to the legacy [PrinterLanguage.tspl] default.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('printer_back_compat_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(PrinterConfigModelAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('legacy-style record with language == null decodes back to TSPL',
      () async {
    // The new adapter always writes 7 fields; to simulate a legacy 6-field
    // record we persist a model with `language: null`. The decoder still
    // reads the field as null because Hive's `read()` produces null for
    // fields the writer omitted, which is exactly the same code path
    // legacy records take through the new adapter (`fields[6] as String?`).
    final Box<PrinterConfigModel> writeBox =
        await Hive.openBox<PrinterConfigModel>('legacy_printers');
    final PrinterConfigModel legacy = PrinterConfigModel(
      id: 'p1',
      name: 'Old XPrinter',
      ip: '192.168.1.10',
      port: 9100,
      isDefault: true,
      timeoutMs: 3000,
    );
    await writeBox.put('p1', legacy);
    await writeBox.close();

    // Re-open and decode through the regular path.
    final Box<PrinterConfigModel> readBox =
        await Hive.openBox<PrinterConfigModel>('legacy_printers');
    final PrinterConfigModel? back = readBox.get('p1');
    expect(back, isNotNull);
    expect(back!.id, 'p1');
    expect(back.name, 'Old XPrinter');
    expect(back.language, isNull);

    final PrinterLanguage decoded =
        PrinterLanguage.fromWireToken(back.language);
    expect(decoded, PrinterLanguage.tspl,
        reason: 'A null wireToken must decode to the legacy TSPL default');

    // And a record explicitly tagged ZPL decodes correctly too.
    final PrinterConfigModel zebraRecord = PrinterConfigModel(
      id: 'p2',
      name: 'Zebra ZD230t',
      ip: '192.168.1.11',
      port: 9100,
      isDefault: false,
      timeoutMs: 3000,
      language: 'zpl',
    );
    await readBox.put('p2', zebraRecord);
    final PrinterConfigModel? zebraBack = readBox.get('p2');
    expect(zebraBack, isNotNull);
    expect(PrinterLanguage.fromWireToken(zebraBack!.language),
        PrinterLanguage.zpl);
    await readBox.close();
  });

  test('round-trip: entity → model → entity preserves language', () async {
    final Box<PrinterConfigModel> box =
        await Hive.openBox<PrinterConfigModel>('roundtrip_printers');

    for (final PrinterLanguage lang in PrinterLanguage.values) {
      final PrinterConfigModel m = PrinterConfigModel(
        id: lang.wireToken,
        name: 'P',
        ip: '10.0.0.1',
        port: 9100,
        isDefault: false,
        timeoutMs: 3000,
        language: lang.wireToken,
      );
      await box.put(lang.wireToken, m);
    }

    for (final PrinterLanguage lang in PrinterLanguage.values) {
      final PrinterConfigModel? loaded = box.get(lang.wireToken);
      expect(loaded, isNotNull);
      expect(loaded!.toEntity().language, lang);
    }
    await box.close();
  });
}
