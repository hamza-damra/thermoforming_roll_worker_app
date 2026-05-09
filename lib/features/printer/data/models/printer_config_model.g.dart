// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printer_config_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrinterConfigModelAdapter extends TypeAdapter<PrinterConfigModel> {
  @override
  final int typeId = 10;

  @override
  PrinterConfigModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrinterConfigModel(
      id: fields[0] as String,
      name: fields[1] as String,
      ip: fields[2] as String,
      port: fields[3] as int,
      isDefault: fields[4] as bool,
      timeoutMs: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PrinterConfigModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.ip)
      ..writeByte(3)
      ..write(obj.port)
      ..writeByte(4)
      ..write(obj.isDefault)
      ..writeByte(5)
      ..write(obj.timeoutMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterConfigModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
