import 'package:hive/hive.dart';

import '../../domain/entities/printer_config.dart';

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

  factory PrinterConfigModel.fromEntity(PrinterConfig entity) {
    return PrinterConfigModel(
      id: entity.id,
      name: entity.name,
      ip: entity.ip,
      port: entity.port,
      isDefault: entity.isDefault,
      timeoutMs: entity.timeoutMs,
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
    );
  }
}
