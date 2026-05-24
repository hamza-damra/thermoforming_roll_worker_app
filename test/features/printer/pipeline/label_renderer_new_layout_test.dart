import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/label_preset.dart';
import 'package:thermoforming_roll_worker/features/printer/domain/entities/roll_label_data.dart';
import 'package:thermoforming_roll_worker/features/printer/pipeline/label_renderer.dart';
import 'package:thermoforming_roll_worker/features/printer/pipeline/unit_converter.dart';

/// Sanity tests for the structured 100×100 mm layout ported from
/// `RollProductionApp`. The renderer uses Flutter's `TextPainter` and the
/// `image` package so it needs `TestWidgetsFlutterBinding`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const LabelPreset preset = LabelPreset(
    id: 'default_100x100',
    name: '100 × 100 mm',
    widthMm: 100,
    heightMm: 100,
    marginMm: 4,
  );

  RollLabelData dataFor({bool isScrap = false}) => RollLabelData.fromParts(
        generatedRollId: '003000000451',
        rollTypeRollCode: 'TP-9 White',
        isScrap: isScrap,
        createdAt: DateTime.utc(2026, 5, 11, 14, 30),
      );

  test('new layout produces a bitmap with the preset dimensions in dots',
      () async {
    final LabelRenderer renderer = LabelRenderer();
    final LabelRenderResult result = await renderer.render(
      value: '003000000451',
      preset: preset,
      labelData: dataFor(),
    );

    final int expectedHeight = UnitConverter.mmToDots(100);
    // Width is padded up to the nearest byte multiple, so we expect
    // monochromeBytes.length == widthBytes * height.
    expect(result.height, expectedHeight);
    expect(result.monochromeBytes.length, result.widthBytes * result.height);
    expect(result.widthBytes, greaterThan(0));
  });

  test(
    'grinding remainder (isScrap=true) produces a bitmap that differs from '
    'the standard label (the scrap icon shifts the serial layout and adds '
    'ink — exact pixel counts depend on font hinting, so we only assert '
    'the two payloads are not byte-identical)',
    () async {
      final LabelRenderer renderer = LabelRenderer();
      final LabelRenderResult standard = await renderer.render(
        value: '003000000451',
        preset: preset,
        labelData: dataFor(),
      );
      final LabelRenderResult grinding = await renderer.render(
        value: '003000000451',
        preset: preset,
        labelData: dataFor(isScrap: true),
      );

      expect(standard.monochromeBytes.length, grinding.monochromeBytes.length);
      // At least one byte must differ between the two renders.
      bool differs = false;
      for (int i = 0; i < standard.monochromeBytes.length; i++) {
        if (standard.monochromeBytes[i] != grinding.monochromeBytes[i]) {
          differs = true;
          break;
        }
      }
      expect(differs, true,
          reason: 'isScrap should change the rendered bitmap');
    },
  );

  test('legacy path still works when labelData is omitted', () async {
    final LabelRenderer renderer = LabelRenderer();
    final LabelRenderResult result = await renderer.render(
      value: '003000000451',
      preset: preset,
      topText: 'TP-9',
      bottomText: 'TP-9 White',
      sideText: '003000000451',
    );
    expect(result.height, UnitConverter.mmToDots(100));
    expect(result.monochromeBytes.length, result.widthBytes * result.height);
  });
}
