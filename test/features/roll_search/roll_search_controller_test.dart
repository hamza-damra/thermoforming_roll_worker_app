import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/features/roll_search/data/roll_search_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/entities/roll_search_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/roll_search_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_search/presentation/controllers/roll_search_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_search/presentation/controllers/roll_search_state.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

import 'roll_search_fakes.dart';

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

ProviderContainer _container(
  RollSearchRepository repo, {
  RollWorkerAuthRepository? authRepo,
}) {
  final c = ProviderContainer(
    overrides: <Override>[
      rollSearchRepositoryProvider.overrideWithValue(repo),
      if (authRepo != null)
        rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

RollSearchController _notifier(ProviderContainer c) =>
    c.read(rollSearchControllerProvider(kSearchShiftLineId).notifier);

RollSearchState _state(ProviderContainer c) =>
    c.read(rollSearchControllerProvider(kSearchShiftLineId));

void main() {
  test('starts idle', () {
    final c = _container(FakeRollSearchRepository(<RollSearchResult>[]));
    expect(_state(c), isA<RollSearchIdle>());
  });

  test('FOUND auto-selects the single roll', () async {
    final m = searchMatch();
    final repo = FakeRollSearchRepository(<RollSearchResult>[
      RollSearchSuccess(foundOutcome(m)),
    ]);
    final c = _container(repo);

    await _notifier(c).search(kSearchQuery);

    final s = _state(c) as RollSearchLoaded;
    expect(s.selectedRollNumber, '777000000011');
    expect(s.selected, m);
    expect(s.query, kSearchQuery);
    expect(repo.queries, <Object>[kSearchQuery]);
  });

  test('MULTIPLE_MATCHES selects nothing until select() is called', () async {
    final repo = FakeRollSearchRepository(<RollSearchResult>[
      RollSearchSuccess(
        multipleOutcome(<RollSearchMatch>[
          searchMatch(rollId: 1, generatedRollId: '777000000001'),
          searchMatch(rollId: 2, generatedRollId: '777000000002'),
        ]),
      ),
    ]);
    final c = _container(repo);

    await _notifier(c).search(kSearchQuery);
    var s = _state(c) as RollSearchLoaded;
    expect(s.selectedRollNumber, isNull);
    expect(s.selected, isNull);

    _notifier(c).select('777000000002');
    s = _state(c) as RollSearchLoaded;
    expect(s.selectedRollNumber, '777000000002');
    expect(s.selected!.rollId, 2);
  });

  test('select() is ignored outside a loaded state', () {
    final c = _container(FakeRollSearchRepository(<RollSearchResult>[]));
    _notifier(c).select('777000000001');
    expect(_state(c), isA<RollSearchIdle>());
  });

  test('NOT_FOUND loads an empty outcome with nothing selected', () async {
    final c = _container(
      FakeRollSearchRepository(<RollSearchResult>[
        RollSearchSuccess(notFoundOutcome()),
      ]),
    );
    await _notifier(c).search(kSearchQuery);
    final s = _state(c) as RollSearchLoaded;
    expect(s.outcome.matches, isEmpty);
    expect(s.selected, isNull);
  });

  test('a failure becomes RollSearchFailed and keeps the query', () async {
    final c = _container(
      FakeRollSearchRepository(<RollSearchResult>[
        const RollSearchFailure(
          BusinessFailure(code: ErrorCode.rollProductionTimeInvalid),
        ),
      ]),
    );
    await _notifier(c).search(kSearchQuery);
    final s = _state(c) as RollSearchFailed;
    expect((s.failure as BusinessFailure).code, ErrorCode.rollProductionTimeInvalid);
    expect(s.query, kSearchQuery);
  });

  test('refresh re-runs the last query and keeps the chosen roll', () async {
    final two = <RollSearchMatch>[
      searchMatch(rollId: 1, generatedRollId: '777000000001'),
      searchMatch(rollId: 2, generatedRollId: '777000000002'),
    ];
    final repo = FakeRollSearchRepository(<RollSearchResult>[
      RollSearchSuccess(multipleOutcome(two)),
      RollSearchSuccess(
        multipleOutcome(<RollSearchMatch>[
          two[0],
          searchMatch(
            rollId: 2,
            generatedRollId: '777000000002',
            mountable: false,
            refusal: const BusinessFailure(
              code: ErrorCode.shiftLineAlreadyHasActiveRoll,
            ),
          ),
        ]),
      ),
    ]);
    final c = _container(repo);

    await _notifier(c).search(kSearchQuery);
    _notifier(c).select('777000000002');
    await _notifier(c).refresh();

    expect(repo.calls, 2);
    expect(repo.queries.last, kSearchQuery);
    final s = _state(c) as RollSearchLoaded;
    expect(s.selectedRollNumber, '777000000002');
    expect(s.selected!.mountable, isFalse);
  });

  test('refresh drops a selection that is no longer among the matches',
      () async {
    final repo = FakeRollSearchRepository(<RollSearchResult>[
      RollSearchSuccess(
        multipleOutcome(<RollSearchMatch>[
          searchMatch(rollId: 1, generatedRollId: '777000000001'),
          searchMatch(rollId: 2, generatedRollId: '777000000002'),
        ]),
      ),
      RollSearchSuccess(
        multipleOutcome(<RollSearchMatch>[
          searchMatch(rollId: 1, generatedRollId: '777000000001'),
          searchMatch(rollId: 3, generatedRollId: '777000000003'),
        ]),
      ),
    ]);
    final c = _container(repo);
    await _notifier(c).search(kSearchQuery);
    _notifier(c).select('777000000002');
    await _notifier(c).refresh();
    expect((_state(c) as RollSearchLoaded).selectedRollNumber, isNull);
  });

  test('refresh with nothing searched does nothing', () async {
    final repo = FakeRollSearchRepository(<RollSearchResult>[]);
    final c = _container(repo);
    await _notifier(c).refresh();
    expect(repo.calls, 0);
    expect(_state(c), isA<RollSearchIdle>());
  });

  test('refresh after a failure retries the failed query', () async {
    final repo = FakeRollSearchRepository(<RollSearchResult>[
      const RollSearchFailure(BusinessFailure(code: ErrorCode.unknown)),
      RollSearchSuccess(foundOutcome(searchMatch())),
    ]);
    final c = _container(repo);
    await _notifier(c).search(kSearchQuery);
    await _notifier(c).refresh();
    expect(_state(c), isA<RollSearchLoaded>());
    expect(repo.calls, 2);
  });

  test('a second search while one is in flight is ignored', () async {
    final repo = FakeRollSearchRepository(<RollSearchResult>[
      RollSearchSuccess(foundOutcome(searchMatch())),
    ])..gate = Completer<void>();
    final c = _container(repo);

    final first = _notifier(c).search(kSearchQuery);
    expect(_state(c), isA<RollSearchLoading>());
    final second = _notifier(c).search(kSearchQuery);
    await second;
    expect(repo.calls, 1);

    repo.gate!.complete();
    await first;
    expect(_state(c), isA<RollSearchLoaded>());
  });

  test('a refresh keeps the previous result in the loading state', () async {
    final repo = FakeRollSearchRepository(<RollSearchResult>[
      RollSearchSuccess(foundOutcome(searchMatch())),
    ]);
    final c = _container(repo);
    await _notifier(c).search(kSearchQuery);
    repo.gate = Completer<void>();
    final pending = _notifier(c).refresh();
    final loading = _state(c) as RollSearchLoading;
    expect(loading.previous, isNotNull);
    repo.gate!.complete();
    await pending;
  });

  test('reset returns to idle', () async {
    final c = _container(
      FakeRollSearchRepository(<RollSearchResult>[
        RollSearchSuccess(foundOutcome(searchMatch())),
      ]),
    );
    await _notifier(c).search(kSearchQuery);
    _notifier(c).reset();
    expect(_state(c), isA<RollSearchIdle>());
  });

  group('session loss', () {
    for (final ErrorCode code in <ErrorCode>[
      ErrorCode.rollWorkerSessionRequired,
      ErrorCode.rollOpSessionTokenMissing,
      ErrorCode.thermoformingShiftLineNotActive,
    ]) {
      test('${code.wireValue} notifies the session registry', () async {
        final authRepo = _MockAuthRepo();
        when(
          () => authRepo.clearStoredToken(kSearchShiftLineId),
        ).thenAnswer((_) async {});
        final c = _container(
          FakeRollSearchRepository(<RollSearchResult>[
            RollSearchFailure(BusinessFailure(code: code)),
          ]),
          authRepo: authRepo,
        );
        await _notifier(c).search(kSearchQuery);
        verify(() => authRepo.clearStoredToken(kSearchShiftLineId)).called(1);
        expect(_state(c), isA<RollSearchFailed>());
      });
    }

    test('a device-key fault or an invalid time does not', () async {
      final authRepo = _MockAuthRepo();
      when(
        () => authRepo.clearStoredToken(any<int>()),
      ).thenAnswer((_) async {});
      for (final ErrorCode code in <ErrorCode>[
        ErrorCode.authInvalidCredentials,
        ErrorCode.rollProductionTimeInvalid,
      ]) {
        final c = _container(
          FakeRollSearchRepository(<RollSearchResult>[
            RollSearchFailure(BusinessFailure(code: code)),
          ]),
          authRepo: authRepo,
        );
        await _notifier(c).search(kSearchQuery);
      }
      verifyNever(() => authRepo.clearStoredToken(any<int>()));
    });
  });

  test('state is per shift line', () async {
    final c = _container(
      FakeRollSearchRepository(<RollSearchResult>[
        RollSearchSuccess(foundOutcome(searchMatch())),
      ]),
    );
    await _notifier(c).search(kSearchQuery);
    expect(
      c.read(rollSearchControllerProvider(kSearchShiftLineId + 1)),
      isA<RollSearchIdle>(),
    );
  });
}
