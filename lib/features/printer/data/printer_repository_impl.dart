import 'package:uuid/uuid.dart';

import '../domain/entities/printer_config.dart';
import '../domain/printer_repository.dart';
import 'models/printer_config_model.dart';
import 'printing_local_storage.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  PrinterRepositoryImpl({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  List<PrinterConfig> getAll() {
    return PrintingLocalStorage.printersBox.values
        .map((PrinterConfigModel m) => m.toEntity())
        .toList();
  }

  @override
  PrinterConfig? getById(String id) {
    return PrintingLocalStorage.printersBox.get(id)?.toEntity();
  }

  @override
  PrinterConfig? getDefault() {
    final List<PrinterConfig> printers = getAll();
    if (printers.isEmpty) return null;
    for (final PrinterConfig p in printers) {
      if (p.isDefault) return p;
    }
    return printers.first;
  }

  @override
  Future<void> save(PrinterConfig printer) async {
    final String id = printer.id.isEmpty ? _uuid.v4() : printer.id;
    final PrinterConfig withId = printer.copyWith(id: id);
    final PrinterConfigModel model = PrinterConfigModel.fromEntity(withId);
    await PrintingLocalStorage.printersBox.put(id, model);
  }

  @override
  Future<void> delete(String id) {
    return PrintingLocalStorage.printersBox.delete(id);
  }

  @override
  Future<void> setDefault(String id) async {
    for (final PrinterConfig printer in getAll()) {
      final bool shouldBeDefault = printer.id == id;
      if (printer.isDefault != shouldBeDefault) {
        await save(printer.copyWith(isDefault: shouldBeDefault));
      }
    }
  }
}
