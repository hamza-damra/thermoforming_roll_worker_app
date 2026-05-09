import 'entities/printer_config.dart';

/// Persistence contract for the configured printers list.
abstract class PrinterRepository {
  List<PrinterConfig> getAll();
  PrinterConfig? getById(String id);
  PrinterConfig? getDefault();
  Future<void> save(PrinterConfig printer);
  Future<void> delete(String id);
  Future<void> setDefault(String id);
}
