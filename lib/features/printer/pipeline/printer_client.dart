import 'dart:io';
import 'dart:typed_data';

import '../core/printing_exception.dart';
import '../domain/entities/label_preset.dart';
import '../domain/entities/printer_config.dart';
import 'label_renderer.dart';
import 'tspl_builder.dart';

/// Sends a TSPL print job to one configured printer over TCP/IP.
///
/// Adapted verbatim from `roll_production_app`'s production-validated
/// pipeline. The two public methods are [print] (renders + sends a label)
/// and [testConnection] (used by the printer-settings screen to verify
/// reachability before saving).
class PrinterClient {
  PrinterClient(this.printer);

  final PrinterConfig printer;

  Future<void> print({
    required String value,
    required LabelPreset preset,
    int copies = 1,
    String? topText,
    String? bottomText,
    String? sideText,
  }) async {
    final LabelRenderer renderer = LabelRenderer();
    final LabelRenderResult render = await renderer.render(
      value: value,
      preset: preset,
      topText: topText,
      bottomText: bottomText,
      sideText: sideText,
    );

    final TsplBuilder builder = TsplBuilder();
    final Uint8List payload = builder.createLabelPrint(
      widthMm: preset.widthMm,
      heightMm: preset.heightMm,
      bitmapWidthBytes: render.widthBytes,
      bitmapHeight: render.height,
      bitmapData: render.monochromeBytes,
      copies: copies,
    );

    await _sendData(payload);
  }

  Future<void> _sendData(Uint8List data) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        printer.ip,
        printer.port,
        timeout: Duration(milliseconds: printer.timeoutMs),
      );
      socket.add(data);
      await socket.flush();
    } on SocketException catch (e) {
      // 110 = Linux ETIMEDOUT; 10060 = Windows WSAETIMEDOUT.
      if (e.osError?.errorCode == 110 || e.osError?.errorCode == 10060) {
        throw PrintingException.connectionTimeout();
      }
      throw PrintingException.connectionFailed(error: e);
    } catch (e) {
      throw PrintingException.sendFailed(error: e);
    } finally {
      try {
        socket?.destroy();
      } catch (_) {
        // intentionally swallowed — socket cleanup never blocks success
      }
    }
  }

  Future<bool> testConnection() async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        printer.ip,
        printer.port,
        timeout: Duration(milliseconds: printer.timeoutMs),
      );
      return true;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {
        // intentionally swallowed
      }
    }
  }
}
