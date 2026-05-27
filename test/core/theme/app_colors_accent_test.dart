import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_colors.dart';

void main() {
  group('AppColors.accentForLine', () {
    test('returns the same color for the same palletizingLineId across calls',
        () {
      expect(
        AppColors.accentForLine(palletizingLineId: 7),
        AppColors.accentForLine(palletizingLineId: 7),
      );
    });

    test('maps palletizingLineId stably via modulo 6', () {
      expect(
        AppColors.accentForLine(palletizingLineId: 0),
        AppColors.lineAccentPalette[0],
      );
      expect(
        AppColors.accentForLine(palletizingLineId: 1),
        AppColors.lineAccentPalette[1],
      );
      expect(
        AppColors.accentForLine(palletizingLineId: 6),
        AppColors.lineAccentPalette[0],
        reason: '6 % 6 == 0',
      );
      expect(
        AppColors.accentForLine(palletizingLineId: 13),
        AppColors.lineAccentPalette[1],
        reason: '13 % 6 == 1',
      );
    });

    test('falls back to thermoformingLineId when palletizing id is null', () {
      expect(
        AppColors.accentForLine(thermoformingLineId: 3),
        AppColors.lineAccentPalette[3],
      );
    });

    test('falls back to hash of palletizingLineCode when ids are null', () {
      final result = AppColors.accentForLine(palletizingLineCode: 'TF_LINE_1');
      expect(AppColors.lineAccentPalette, contains(result));
    });

    test('returns a non-null, non-transparent color when every key is null',
        () {
      final fallback = AppColors.accentForLine();
      expect(fallback, AppColors.lineAccentPalette[0]);
    });

    test('treats negative ids as positive (no array index crash)', () {
      expect(
        AppColors.accentForLine(palletizingLineId: -1),
        AppColors.lineAccentPalette[1],
      );
    });

    test('palette has exactly 6 distinct entries', () {
      expect(AppColors.lineAccentPalette.length, 6);
      expect(AppColors.lineAccentPalette.toSet().length, 6);
    });
  });
}
