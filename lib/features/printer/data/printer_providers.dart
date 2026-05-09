import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/preset_repository.dart';
import '../domain/printer_repository.dart';
import '../pipeline/printer_transport.dart';
import 'preset_repository_impl.dart';
import 'printer_repository_impl.dart';

final Provider<PrinterRepository> printerRepositoryProvider =
    Provider<PrinterRepository>((ref) => PrinterRepositoryImpl());

final Provider<PresetRepository> presetRepositoryProvider =
    Provider<PresetRepository>((ref) => PresetRepositoryImpl());

/// Physical-print transport. Override in tests with a fake to assert
/// orchestrator behavior without hitting a real socket.
final Provider<PrinterTransport> printerTransportProvider =
    Provider<PrinterTransport>((ref) => const TsplSocketPrinterTransport());
