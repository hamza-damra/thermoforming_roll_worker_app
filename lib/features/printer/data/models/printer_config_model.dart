import 'package:hive/hive.dart';

import '../../domain/entities/printer_config.dart';
import '../../domain/entities/printer_language.dart';

part 'printer_config_model.g.dart';

@HiveType(typeId: 10)
class PrinterConfigModel extends HiveObject {
  PrinterConfigModel({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.isDefault,
    required this.timeoutMs,
    this.language,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String ip;

  @HiveField(3)
  final int port;

  @HiveField(4)
  final bool isDefault;

  @HiveField(5)
  final int timeoutMs;

  /// Wire protocol token — nullable for back-compat with the original
  /// 6-field schema (pre multi-protocol support). A `null` value
  /// resolves to [PrinterLanguage.tspl] via [PrinterLanguage.fromWireToken].
  @HiveField(6)
  final String? language;

  factory PrinterConfigModel.fromEntity(PrinterConfig entity) {
    return PrinterConfigModel(
      id: entity.id,
      name: entity.name,
      ip: entity.ip,
      port: entity.port,
      isDefault: entity.isDefault,
      timeoutMs: entity.timeoutMs,
      language: entity.language.wireToken,
    );
  }

  PrinterConfig toEntity() {
    return PrinterConfig(
      id: id,
      name: name,
      ip: ip,
      port: port,
      isDefault: isDefault,
      timeoutMs: timeoutMs,
      language: PrinterLanguage.fromWireToken(language),
    );
  }
}
