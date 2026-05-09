// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label_preset_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LabelPresetModelAdapter extends TypeAdapter<LabelPresetModel> {
  @override
  final int typeId = 11;

  @override
  LabelPresetModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LabelPresetModel(
      id: fields[0] as String,
      name: fields[1] as String,
      widthMm: fields[2] as double,
      heightMm: fields[3] as double,
      marginMm: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, LabelPresetModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.widthMm)
      ..writeByte(3)
      ..write(obj.heightMm)
      ..writeByte(4)
      ..write(obj.marginMm);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelPresetModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
