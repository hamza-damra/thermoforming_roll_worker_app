import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/features/shift_line/data/active_shift_line_options_providers.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/active_shift_line_options_repository.dart';
import 'package:thermoforming_roll_worker/features/shift_line/domain/entities/active_shift_line_option.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/active_shift_line_options_controller.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/active_shift_line_options_state.dart';
import 'package:thermoforming_roll_worker/features/shift_line/presentation/controllers/selected_shift_line_provider.dart';

class _MockRepo extends Mock implements ActiveShiftLineOptionsRepository {}

ActiveShiftLineOption _option(int id, {bool selectable = true}) =>
    ActiveShiftLineOption(
      shiftLineId: id,
      thermoformingShiftId: 100,
      thermoformingLineId: 10,
      thermoformingLineCode: 'TH-0$id',
      thermoformingLineName: 'Thermo $id',
      palletizingLineId: 20,
      palletizingLineCode: 'PL-0$id',
      palletizingLineName: 'Palletizer $id',
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
    );

ProviderContainer _container(ActiveShiftLineOptionsRepository repo) {
  final c = ProviderContainer(
    overrides: <Override>[
      activeShiftLineOptionsRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ActiveShiftLineOptionsController', () {
    test('initial build kicks off a refresh that resolves to Loaded', () async {
      final repo = _MockRepo();
      when(repo.fetch).thenAnswer(
        (_) async => ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
          _option(1),
        ]),
      );
      final container = _container(repo);

      container.read(activeShiftLineOptionsControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(activeShiftLineOptionsControllerProvider);
      expect(state, isA<ActiveShiftLineOptionsLoaded>());
      expect(
        (state as ActiveShiftLineOptionsLoaded).options.single.shiftLineId,
        1,
      );
    });

    test('refresh failure preserves the previous list', () async {
      final repo = _MockRepo();
      int call = 0;
      when(repo.fetch).thenAnswer((_) async {
        call++;
        if (call == 1) {
          return ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
            _option(1),
          ]);
        }
        return const ActiveShiftLineOptionsFailure(NetworkFailure());
      });
      final container = _container(repo);

      container.read(activeShiftLineOptionsControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(activeShiftLineOptionsControllerProvider.notifier)
          .refresh();

      final state = container.read(activeShiftLineOptionsControllerProvider);
      expect(state, isA<ActiveShiftLineOptionsFailureState>());
      expect(
        (state as ActiveShiftLineOptionsFailureState).previous.single.shiftLineId,
        1,
      );
    });

    test(
      'refresh drops disappeared ids from the picker selection set; '
      'survivors are kept',
      () async {
        final repo = _MockRepo();
        int call = 0;
        when(repo.fetch).thenAnswer((_) async {
          call++;
          if (call == 1) {
            return ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
              _option(7),
              _option(8),
            ]);
          }
          // Second fetch only returns id 8 — id 7 should be dropped from the
          // selection set.
          return ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
            _option(8),
          ]);
        });

        final container = _container(repo);

        // Pre-seed the picker selection with both ids.
        container.read(pickerShiftLineSelectionProvider.notifier)
          ..add(7)
          ..add(8);

        container.read(activeShiftLineOptionsControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        // After first refresh, both still present in selection.
        expect(container.read(pickerShiftLineSelectionProvider), <int>{7, 8});

        await container
            .read(activeShiftLineOptionsControllerProvider.notifier)
            .refresh();

        expect(container.read(pickerShiftLineSelectionProvider), <int>{8});
      },
    );

    test(
      'refresh that returns the line as non-selectable drops it from the '
      'selection set',
      () async {
        final repo = _MockRepo();
        when(repo.fetch).thenAnswer(
          (_) async => ActiveShiftLineOptionsSuccess(<ActiveShiftLineOption>[
            _option(7, selectable: false),
          ]),
        );

        final container = _container(repo);
        container.read(pickerShiftLineSelectionProvider.notifier).add(7);

        container.read(activeShiftLineOptionsControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(container.read(pickerShiftLineSelectionProvider), <int>{});
      },
    );
  });
}
