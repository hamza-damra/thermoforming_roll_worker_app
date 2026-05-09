import 'package:hive/hive.dart';

import '../../domain/entities/label_preset.dart';

part 'label_preset_model.g.dart';

@HiveType(typeId: 11)
class LabelPresetModel extends HiveObject {
  LabelPresetModel({
    required this.id,
    required this.name,
    required this.widthMm,
    required this.heightMm,
    required this.marginMm,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double widthMm;

  @HiveField(3)
  final double heightMm;

  @HiveField(4)
  final double marginMm;

  factory LabelPresetModel.fromEntity(LabelPreset entity) {
    return LabelPresetModel(
      id: entity.id,
      name: entity.name,
      widthMm: entity.widthMm,
      heightMm: entity.heightMm,
      marginMm: entity.marginMm,
    );
  }

  LabelPreset toEntity() {
    return LabelPreset(
      id: id,
      name: name,
      widthMm: widthMm,
      heightMm: heightMm,
      marginMm: marginMm,
    );
  }
}
