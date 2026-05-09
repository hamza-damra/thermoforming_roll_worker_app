import '../domain/entities/label_preset.dart';
import '../domain/entities/printer_config.dart';
import 'printer_client.dart';

/// Abstraction over the physical TSPL/socket printing pipeline.
///
/// Production: [TsplSocketPrinterTransport] wraps `PrinterClient`,
/// `LabelRenderer`, and `TsplBuilder` to render and send a TSPL print job
/// to a TCP/IP printer.
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
    String? topText,
    String? bottomText,
    String? sideText,
  });

  Future<bool> testConnection(PrinterConfig printer);
}

/// Default transport that uses [PrinterClient] (which itself wraps
/// `LabelRenderer` + `TsplBuilder` + a `dart:io.Socket`).
class TsplSocketPrinterTransport implements PrinterTransport {
  const TsplSocketPrinterTransport();

  @override
  Future<void> sendPrintJob({
    required PrinterConfig printer,
    required String value,
    required LabelPreset preset,
    int copies = 1,
    String? topText,
    String? bottomText,
    String? sideText,
  }) {
    return PrinterClient(printer).print(
      value: value,
      preset: preset,
      copies: copies,
      topText: topText,
      bottomText: bottomText,
      sideText: sideText,
    );
  }

  @override
  Future<bool> testConnection(PrinterConfig printer) =>
      PrinterClient(printer).testConnection();
}
