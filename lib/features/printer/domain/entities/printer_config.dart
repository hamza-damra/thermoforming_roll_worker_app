import 'package:flutter/foundation.dart';

import '../../core/printing_constants.dart';

/// One TSPL/TCP printer the worker has configured. The Roll Worker app
/// supports multiple saved printers; one can be marked default.
@immutable
class PrinterConfig {
  const PrinterConfig({
    required this.id,
    required this.name,
    required this.ip,
    this.port = PrintingConstants.defaultPort,
    this.isDefault = false,
    this.timeoutMs = PrintingConstants.connectionTimeoutMs,
  });

  final String id;
  final String name;
  final String ip;
  final int port;
  final bool isDefault;
  final int timeoutMs;

  PrinterConfig copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    bool? isDefault,
    int? timeoutMs,
  }) {
    return PrinterConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      isDefault: isDefault ?? this.isDefault,
      timeoutMs: timeoutMs ?? this.timeoutMs,
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
        other.timeoutMs == timeoutMs;
  }

  @override
  int get hashCode => Object.hash(id, name, ip, port, isDefault, timeoutMs);
}
