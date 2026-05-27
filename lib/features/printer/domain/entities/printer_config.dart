import 'package:flutter/foundation.dart';

import '../../core/printing_constants.dart';
import 'printer_language.dart';

/// One TCP printer the worker has configured. The Roll Worker app
/// supports multiple saved printers and two wire protocols (TSPL /
/// Xprinter and ZPL / Zebra) — see [PrinterLanguage]; one can be
/// marked default.
@immutable
class PrinterConfig {
  const PrinterConfig({
    required this.id,
    required this.name,
    required this.ip,
    this.port = PrintingConstants.defaultPort,
    this.isDefault = false,
    this.timeoutMs = PrintingConstants.connectionTimeoutMs,
    this.language = PrinterLanguage.tspl,
  });

  final String id;
  final String name;
  final String ip;
  final int port;
  final bool isDefault;
  final int timeoutMs;

  /// Wire protocol the printer speaks. Drives which builder
  /// (`TsplBuilder` / `ZplBuilder`) the print pipeline routes through.
  final PrinterLanguage language;

  PrinterConfig copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    bool? isDefault,
    int? timeoutMs,
    PrinterLanguage? language,
  }) {
    return PrinterConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      isDefault: isDefault ?? this.isDefault,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrinterConfig &&
        other.id == id &&
        other.name == name &&
        other.ip == ip &&
        other.port == port &&
        other.isDefault == isDefault &&
        other.timeoutMs == timeoutMs &&
        other.language == language;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, ip, port, isDefault, timeoutMs, language);
}
