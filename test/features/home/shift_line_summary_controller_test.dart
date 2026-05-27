import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/controllers/shift_line_summary_controller.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/controllers/shift_line_summary_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int _shiftLineId = 101;

ShiftLineSummary _summary() => const ShiftLineSummary(
  shiftLineId: _shiftLineId,
  thermoformingLineCode: 'TH-01',
  thermoformingLineName: 'خط التشكيل 1',
  completedRollsInSession: 5,
  completedRollsByCurrentWorker: 2,
);

ProviderContainer _makeContainer(ShiftLineSummaryRepository repo) {
  final authRepo = _MockAuthRepo();
  when(() => authRepo.clearStoredToken(any())).thenAnswer((_) async {});
  return ProviderContainer(
    overrides: [
      shiftLineSummaryRepositoryProvider.overrideWithValue(repo),
      rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
    ],
  );
}

void main() {
  group('ShiftLineSummaryController', () {
    test('initial state is SummaryLoading', () {
      final repo = _MockSummaryRepo();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      expect(
        container.read(shiftLineSummaryControllerProvider(_shiftLineId)),
        isA<SummaryLoading>(),
      );
    });

    test('load() transitions Loading → Loaded on success', () async {
      final repo = _MockSummaryRepo();
      when(() => repo.fetchSummary(shiftLineId: _shiftLineId))
          .thenAnswer((_) async => SummarySuccess(_summary()));

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .load();

      final state = container.read(shiftLineSummaryControllerProvider(_shiftLineId));
      expect(state, isA<SummaryLoaded>());
      expect((state as SummaryLoaded).summary.thermoformingLineCode, 'TH-01');
      expect(state.isRefreshing, isFalse);
    });

    test('load() transitions Loading → SummaryError on first-load failure', () async {
      final repo = _MockSummaryRepo();
      when(() => repo.fetchSummary(shiftLineId: _shiftLineId)).thenAnswer(
        (_) async => const SummaryFailure(NetworkFailure(cause: 'timeout')),
      );

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .load();

      expect(
        container.read(shiftLineSummaryControllerProvider(_shiftLineId)),
        isA<SummaryError>(),
      );
    });

    test('refresh() keeps SummaryLoaded with isRefreshing=true during fetch', () async {
      final repo = _MockSummaryRepo();
      // First load succeeds.
      when(() => repo.fetchSummary(shiftLineId: _shiftLineId))
          .thenAnswer((_) async => SummarySuccess(_summary()));

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .load();

      // Subsequent refresh also succeeds; state stays Loaded throughout.
      await container
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .refresh();

      final state = container.read(shiftLineSummaryControllerProvider(_shiftLineId));
      expect(state, isA<SummaryLoaded>());
      expect((state as SummaryLoaded).isRefreshing, isFalse);
      // fetch called twice (load + refresh).
      verify(() => repo.fetchSummary(shiftLineId: _shiftLineId)).called(2);
    });

    test('refresh() failure while loaded stays on prior SummaryLoaded data', () async {
      final repo = _MockSummaryRepo();
      // First load succeeds.
      when(() => repo.fetchSummary(shiftLineId: _shiftLineId))
          .thenAnswer((_) async => SummarySuccess(_summary()));

      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .load();

      // Second call (refresh) fails.
      when(() => repo.fetchSummary(shiftLineId: _shiftLineId)).thenAnswer(
        (_) async => const SummaryFailure(NetworkFailure(cause: 'timeout')),
      );

      await container
          .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
          .refresh();

      // Still loaded with prior data, not in error.
      final state = container.read(shiftLineSummaryControllerProvider(_shiftLineId));
      expect(state, isA<SummaryLoaded>());
      expect((state as SummaryLoaded).isRefreshing, isFalse);
      expect(state.summary.thermoformingLineCode, 'TH-01');
    });

    test(
      'session-loss error code on first load leaves controller in SummaryError',
      () async {
        final repo = _MockSummaryRepo();

        when(() => repo.fetchSummary(shiftLineId: _shiftLineId)).thenAnswer(
          (_) async => const SummaryFailure(
            BusinessFailure(code: ErrorCode.rollWorkerSessionRequired),
          ),
        );

        final container = _makeContainer(repo);
        addTearDown(container.dispose);

        await container
            .read(shiftLineSummaryControllerProvider(_shiftLineId).notifier)
            .load();

        expect(
          container.read(shiftLineSummaryControllerProvider(_shiftLineId)),
          isA<SummaryError>(),
        );
      },
    );
  });
}
