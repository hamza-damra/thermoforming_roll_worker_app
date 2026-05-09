import 'entities/label_preset.dart';

/// Persistence contract for worker-defined label presets (built-in
/// presets are statically defined in [DefaultPresets]).
abstract class PresetRepository {
  List<LabelPreset> getAll();
  LabelPreset? getById(String id);
  Future<void> save(LabelPreset preset);
  Future<void> delete(String id);
}
