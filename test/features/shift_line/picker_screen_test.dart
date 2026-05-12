import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/active_shift_line_options_providers.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/active_shift_line_options_repository.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/active_shift_line_option.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/selected_shift_line_provider.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/screens/active_shift_line_picker_screen.dart';

class _MockRepo extends Mock implements ActiveShiftLineOptionsRepository {}

ActiveShiftLineOption _option({
  int shiftLineId = 500,
  String code = 'TH-01',
  String name = 'Thermo 1',
  bool selectable = true,
  int? existingOpId,
  String? existingOpName,
}) => ActiveShiftLineOption(
  shiftLineId: shiftLineId,
  thermoformingShiftId: 100,
  thermoformingLineId: 10,
  thermoformingLineCode: code,
  thermoformingLineName: name,
  palletizingLineId: 20,
  palletizingLineCode: 'PL-01',
  palletizingLineName: 'Palletizer 1',
  currentProductTypeId: 50,
  currentProductTypeName: 'Cup-200ml',
  currentRollId: null,
  currentRollGeneratedRollId: null,
  currentRollTypeCode: null,
  currentRollTypeName: null,
  currentRollLastKnownWeightKg: null,
  operatorId: 7,
  operatorName: 'محمد',
  shiftLineStatus: 'ACTIVE',
  selectable: selectable,
  blockingReason: null,
  existingSessionOperatorId: existingOpId,
  existingSessionOperatorName: existingOpName,
);

ActiveShiftLineOption _mountedOption() => ActiveShiftLineOption(
  shiftLineId: 501,
  thermoformingShiftId: 100,
  thermoformingLineId: 11,
  thermoformingLineCode: 'TH-02',
  thermoformingLineName: 'Thermo 2',
  palletizingLineId: 21,
  palletizingLineCode: 'PL-02',
  palletizingLineName: 'Palletizer 2',
  currentProductTypeId: 50,
  currentProductTypeName: 'Cup-200ml',
  currentRollId: 900,
  currentRollGeneratedRollId: '001000000123',
  currentRollTypeCode: 'RT-A',
  currentRollTypeName: 'Regular Black',
  currentRollLastKnownWeightKg: 180.5,
  operatorId: 7,
  operatorName: 'محمد',
  shiftLineStatus: 'ACTIVE',
  selectable: true,
  blockingReason: null,
);

Widget _wrapped(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      locale: Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ActiveShiftLinePickerScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('empty result → renders the prescribed Arabic waiting copy', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => const ActiveShiftLineOptionsSuccess(
        <ActiveShiftLineOption>[],
      ),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        activeShiftLineOptionsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrapped(container));
    await tester.pumpAndSettle();

    expect(find.text('بانتظار فتح خط من تطبيق المشغّل'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('rows render line, palletizing, product, operator', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
        _option(),
      ]),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        activeShiftLineOptionsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrapped(container));
    await tester.pumpAndSettle();

    expect(find.text('Thermo 1 (TH-01)'), findsOneWidget);
    expect(find.text('Palletizer 1 (PL-01)'), findsOneWidget);
    expect(find.text('Cup-200ml'), findsOneWidget);
    expect(find.text('محمد'), findsOneWidget);
    // Roll section is omitted when no roll is mounted.
    expect(find.text('الرول الحالي'), findsNothing);
  });

  testWidgets(
    'mounted-roll fields render and weight is shown with kg suffix',
    (tester) async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
          _mountedOption(),
        ]),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          activeShiftLineOptionsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapped(container));
      await tester.pumpAndSettle();

      expect(find.text('الرول الحالي'), findsOneWidget);
      expect(find.text('001000000123'), findsOneWidget);
      expect(find.text('Regular Black'), findsOneWidget);
      expect(find.text('180.5 kg'), findsOneWidget);
    },
  );

  testWidgets('CTA disabled when no rows ticked, dynamic copy on count', (
    tester,
  ) async {
    final repo = _MockRepo();
    when(repo.fetch).thenAnswer(
      (_) async => ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
        _option(shiftLineId: 500, code: 'TH-01', name: 'Thermo 1'),
        _option(shiftLineId: 501, code: 'TH-02', name: 'Thermo 2'),
      ]),
    );
    final container = ProviderContainer(
      overrides: <Override>[
        activeShiftLineOptionsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_wrapped(container));
    await tester.pumpAndSettle();

    // 0 selected → disabled, prompt copy.
    expect(find.text('اختر على الأقل خطاً واحداً'), findsOneWidget);

    // Tick the first row's checkbox.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(container.read(pickerShiftLineSelectionProvider), <int>{500});
    expect(find.text('متابعة'), findsOneWidget);

    // Tick the second row.
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(container.read(pickerShiftLineSelectionProvider), <int>{500, 501});
    expect(find.text('متابعة بـ 2 خطوط'), findsOneWidget);
  });

  testWidgets(
    'existingSessionOperatorName renders the conflict badge with prefix',
    (tester) async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
          _option(
            shiftLineId: 500,
            existingOpId: 77,
            existingOpName: 'يوسف',
          ),
        ]),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          activeShiftLineOptionsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapped(container));
      await tester.pumpAndSettle();

      expect(find.textContaining('مستخدم من:'), findsOneWidget);
      expect(find.textContaining('يوسف'), findsOneWidget);
    },
  );

  testWidgets(
    'failure renders Arabic mapped message with retry affordance',
    (tester) async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => const ActiveShiftLineOptionsFailure(NetworkFailure()),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          activeShiftLineOptionsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapped(container));
      await tester.pumpAndSettle();

      expect(
        find.text('لا يوجد اتصال بالخادم، سيتم إعادة المحاولة تلقائيًا'),
        findsOneWidget,
      );
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    },
  );

  testWidgets(
    'non-selectable row renders the checkbox disabled and shows blocking reason',
    (tester) async {
      const reason = 'الخط مغلق من قبل المشغّل';
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => const ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
          ActiveShiftLineOption(
            shiftLineId: 700,
            thermoformingShiftId: 100,
            thermoformingLineId: 12,
            thermoformingLineCode: 'TH-03',
            thermoformingLineName: 'Thermo 3',
            palletizingLineId: 22,
            palletizingLineCode: 'PL-03',
            palletizingLineName: 'Palletizer 3',
            currentProductTypeId: 50,
            currentProductTypeName: 'Cup-200ml',
            currentRollId: null,
            currentRollGeneratedRollId: null,
            currentRollTypeCode: null,
            currentRollTypeName: null,
            currentRollLastKnownWeightKg: null,
            operatorId: 7,
            operatorName: 'محمد',
            shiftLineStatus: 'ACTIVE',
            selectable: false,
            blockingReason: reason,
          ),
        ]),
      );
      final container = ProviderContainer(
        overrides: <Override>[
          activeShiftLineOptionsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_wrapped(container));
      await tester.pumpAndSettle();

      expect(find.text(reason), findsOneWidget);
      final Checkbox cb = tester.widget(find.byType(Checkbox));
      expect(cb.onChanged, isNull);
    },
  );
}
