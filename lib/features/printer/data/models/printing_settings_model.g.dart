// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'printing_settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrintingSettingsModelAdapter extends TypeAdapter<PrintingSettingsModel> {
  @override
  final int typeId = 12;

  @override
  PrintingSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrintingSettingsModel(
      selectedPrinterId: fields[0] as String?,
      selectedPresetId: fields[1] as String?,
      copies: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PrintingSettingsModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.selectedPrinterId)
      ..writeByte(1)
      ..write(obj.selectedPresetId)
      ..writeByte(2)
      ..write(obj.copies);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintingSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
