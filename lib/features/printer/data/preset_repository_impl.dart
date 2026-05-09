import 'package:uuid/uuid.dart';

import '../domain/entities/label_preset.dart';
import '../domain/preset_repository.dart';
import 'models/label_preset_model.dart';
import 'printing_local_storage.dart';

class PresetRepositoryImpl implements PresetRepository {
  PresetRepositoryImpl({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  List<LabelPreset> getAll() {
    final List<LabelPreset> built = List<LabelPreset>.from(DefaultPresets.all);
    final List<LabelPreset> custom = PrintingLocalStorage.presetsBox.values
        .map((LabelPresetModel m) => m.toEntity())
        .toList();
    return <LabelPreset>[...built, ...custom];
  }

  @override
  LabelPreset? getById(String id) {
    final LabelPreset? builtIn = DefaultPresets.getById(id);
    if (builtIn != null) return builtIn;
    return PrintingLocalStorage.presetsBox.get(id)?.toEntity();
  }

  @override
  Future<void> save(LabelPreset preset) async {
    if (DefaultPresets.getById(preset.id) != null) {
      // Built-in presets are immutable. Worker-defined ones go to the box.
      return;
    }
    final String id = preset.id.isEmpty ? _uuid.v4() : preset.id;
    final LabelPreset withId = preset.copyWith(id: id);
    final LabelPresetModel model = LabelPresetModel.fromEntity(withId);
    await PrintingLocalStorage.presetsBox.put(id, model);
  }

  @override
  Future<void> delete(String id) {
    if (DefaultPresets.getById(id) != null) {
      // Built-ins cannot be deleted.
      return Future<void>.value();
    }
    return PrintingLocalStorage.presetsBox.delete(id);
  }
}
