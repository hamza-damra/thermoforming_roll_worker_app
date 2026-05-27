import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/util/line_label_mapper.dart';

void main() {
  group('LineLabelMapper.friendlyLineLabel (bottom-nav tab strip)', () {
    test('maps known thermoforming codes to Arabic line labels', () {
      expect(
        LineLabelMapper.friendlyLineLabel(
          thermoformingLineCode: 'TF_LINE_1',
          thermoformingLineName: null,
          oneBasedIndex: 1,
        ),
        'خط 1',
      );
      expect(
        LineLabelMapper.friendlyLineLabel(
          thermoformingLineCode: 'TF_LINE_2',
          thermoformingLineName: null,
          oneBasedIndex: 2,
        ),
        'خط 2',
      );
    });

    test('mapping wins over backend display name for known codes', () {
      expect(
        LineLabelMapper.friendlyLineLabel(
          thermoformingLineCode: 'TF_LINE_1',
          thermoformingLineName: 'خط التشكيل 1',
          oneBasedIndex: 1,
        ),
        'خط 1',
      );
    });

    test('falls back to backend display name for unknown codes', () {
      expect(
        LineLabelMapper.friendlyLineLabel(
          thermoformingLineCode: 'TF_LINE_9',
          thermoformingLineName: 'خط الاختبار',
          oneBasedIndex: 3,
        ),
        'خط الاختبار',
      );
    });

    test('falls back to "خط N" when no code and no name', () {
      expect(
        LineLabelMapper.friendlyLineLabel(
          thermoformingLineCode: null,
          thermoformingLineName: null,
          oneBasedIndex: 4,
        ),
        'خط 4',
      );
    });

    test('empty backend name is treated as missing', () {
      expect(
        LineLabelMapper.friendlyLineLabel(
          thermoformingLineCode: 'TF_LINE_X',
          thermoformingLineName: '',
          oneBasedIndex: 5,
        ),
        'خط 5',
      );
    });
  });

  group('LineLabelMapper.friendlyMachineName (centered top header)', () {
    test('maps TF_LINE_1 to ماكينة A', () {
      expect(
        LineLabelMapper.friendlyMachineName(
          thermoformingLineCode: 'TF_LINE_1',
          thermoformingLineName: null,
          oneBasedIndex: 1,
        ),
        'ماكينة A',
      );
    });

    test('maps TF_LINE_2 to ماكينة B', () {
      expect(
        LineLabelMapper.friendlyMachineName(
          thermoformingLineCode: 'TF_LINE_2',
          thermoformingLineName: null,
          oneBasedIndex: 2,
        ),
        'ماكينة B',
      );
    });

    test('falls back to backend name for unknown codes', () {
      expect(
        LineLabelMapper.friendlyMachineName(
          thermoformingLineCode: 'TF_LINE_9',
          thermoformingLineName: 'ماكينة الاختبار',
          oneBasedIndex: 3,
        ),
        'ماكينة الاختبار',
      );
    });

    test('falls back to friendly line label when nothing else matches', () {
      expect(
        LineLabelMapper.friendlyMachineName(
          thermoformingLineCode: null,
          thermoformingLineName: null,
          oneBasedIndex: 7,
        ),
        'خط 7',
      );
    });
  });
}
