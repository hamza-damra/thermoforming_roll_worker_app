import 'package:hive/hive.dart';

part 'printing_settings_model.g.dart';

@HiveType(typeId: 12)
class PrintingSettingsModel extends HiveObject {
  PrintingSettingsModel({
    this.selectedPrinterId,
    this.selectedPresetId,
    this.copies = 1,
  });

  @HiveField(0)
  String? selectedPrinterId;

  @HiveField(1)
  String? selectedPresetId;

  @HiveField(2)
  int copies;
}
