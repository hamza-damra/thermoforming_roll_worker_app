import '../domain/entities/label_preset.dart';
import '../domain/entities/printer_config.dart';
import '../domain/entities/roll_label_data.dart';
import 'printer_client.dart';

/// Abstraction over the physical TSPL/ZPL/socket printing pipeline.
///
/// Production: [TsplSocketPrinterTransport] wraps `PrinterClient`,
/// `LabelRenderer`, and the matching command builder to render and send a
/// print job to a TCP/IP printer.
///
/// Tests: substitute via Riverpod override with a fake transport that
/// records calls or simulates connection / send failures without hitting
/// any real socket.
abstract class PrinterTransport {
  Future<void> sendPrintJob({
    required PrinterConfig printer,
    required String value,
    required LabelPreset preset,
    int copies = 1,
    // Structured layout (preferred). When non-null the renderer uses the
    // new 100×100 mm structured layout; the `topText`/`bottomText`/
    // `sideText` params are ignored.
    RollLabelData? labelData,
    String? topText,
    String? bottomText,
    String? sideText,
  });

  Future<bool> testConnection(PrinterConfig printer);
}

/// Default transport that uses [PrinterClient] (which itself wraps
/// `LabelRenderer` + the TSPL/ZPL builders + a `dart:io.Socket`).
class TsplSocketPrinterTransport implements PrinterTransport {
  const TsplSocketPrinterTransport();

  @override
  Future<void> sendPrintJob({
    required PrinterConfig printer,
    required String value,
    required LabelPreset preset,
    int copies = 1,
    RollLabelData? labelData,
    String? topText,
    String? bottomText,
    String? sideText,
  }) {
    return PrinterClient(printer).print(
      value: value,
      preset: preset,
      copies: copies,
      labelData: labelData,
      topText: topText,
      bottomText: bottomText,
      sideText: sideText,
    );
  }

  @override
  Future<bool> testConnection(PrinterConfig printer) =>
      PrinterClient(printer).testConnection();
}
