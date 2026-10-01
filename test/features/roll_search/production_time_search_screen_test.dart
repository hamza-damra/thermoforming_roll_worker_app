import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/errors/app_failure.dart';
import 'package:thermoforming_roll_worker/core/errors/error_code.dart';
import 'package:thermoforming_roll_worker/core/errors/error_messages_ar.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/data/roll_scan_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/entities/roll_scan_warning.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/domain/roll_scan_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/controllers/roll_scan_controller.dart';
import 'package:thermoforming_roll_worker/features/roll_scan/presentation/controllers/roll_scan_state.dart';
import 'package:thermoforming_roll_worker/features/roll_search/data/roll_search_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/entities/roll_search_outcome.dart';
import 'package:thermoforming_roll_worker/features/roll_search/domain/roll_search_repository.dart';
import 'package:thermoforming_roll_worker/features/roll_search/presentation/screens/production_time_search_screen.dart';

import 'roll_search_fakes.dart';

const String _rollNo = '777000000011';

// 09:00 UTC on 30 Sep 2026 is 12:00 in the factory, so the form is prefilled
// with year 2026 and month 9.
final DateTime _now = DateTime.utc(2026, 9, 30, 9);

const String _mountedSnack = 'تم تركيب الرول بنجاح';

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Hosts the screen one route above a home page, so a pop is observable.
Future<void> _pump(
  WidgetTester tester, {
  required FakeRollSearchRepository search,
  FakeRollScanRepository? scan,
}) async {
  _tallSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        rollSearchRepositoryProvider.overrideWithValue(search),
        rollScanRepositoryProvider.overrideWithValue(
          scan ?? FakeRollScanRepository(<RollScanResult>[]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('host.open'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductionTimeSearchScreen(
                      shiftLineId: kSearchShiftLineId,
                      now: _now,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('host.open')));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String field, String text) async {
  await tester.enterText(find.byKey(Key('productionTimeForm.$field')), text);
  await tester.pump();
}

/// Fills 30-09-2026 02:05 مساء and presses بحث.
Future<void> _searchValid(WidgetTester tester) async {
  await _type(tester, 'day', '30');
  await _type(tester, 'hour', '2');
  await _type(tester, 'minute', '05');
  await tester.tap(find.byKey(const Key('productionTimeForm.period.pm')));
  await tester.pump();
  await tester.tap(find.text('بحث'));
  await tester.pumpAndSettle();
}

Finder get _mountButton => find.byKey(const Key('rollSearchMatchCard.mount'));
Finder get _screen => find.byType(ProductionTimeSearchScreen);

RollScanFailure _scanFailure(ErrorCode code, {Map<String, Object?>? details}) =>
    RollScanFailure(
      BusinessFailure(code: code, statusCode: 409, details: details),
    );

void main() {
  group('the form', () {
    testWidgets('prefills year and month from the factory date, not the day', (
      tester,
    ) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(notFoundOutcome()),
        ]),
      );
      TextField field(String f) => tester.widget<TextField>(
        find.byKey(Key('productionTimeForm.$f')),
      );
      expect(field('year').controller!.text, '2026');
      expect(field('month').controller!.text, '9');
      expect(field('day').controller!.text, isEmpty);
      // Nothing is preselected for صباحاً / مساء and no error shows yet.
      expect(find.byKey(const Key('productionTimeForm.error')), findsNothing);
    });

    testWidgets('shows the label preview once the input is valid', (
      tester,
    ) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(notFoundOutcome()),
        ]),
      );
      expect(
        find.byKey(const Key('productionTimeForm.labelPreview')),
        findsNothing,
      );
      await _type(tester, 'day', '30');
      await _type(tester, 'hour', '2');
      await _type(tester, 'minute', '05');
      await tester.tap(find.byKey(const Key('productionTimeForm.period.pm')));
      await tester.pump();
      final Text preview = tester.widget<Text>(
        find.byKey(const Key('productionTimeForm.labelPreview')),
      );
      expect(preview.data, contains('30-09-2026'));
      expect(preview.data, contains('02:05 مساء'));
    });
  });

  group('client-side validation', () {
    testWidgets('31 April shows the Arabic error and never searches', (
      tester,
    ) async {
      final search = FakeRollSearchRepository(<RollSearchResult>[
        RollSearchSuccess(notFoundOutcome()),
      ]);
      await _pump(tester, search: search);
      await _type(tester, 'month', '4');
      await _type(tester, 'day', '31');
      await _type(tester, 'hour', '2');
      await _type(tester, 'minute', '05');
      await tester.tap(find.byKey(const Key('productionTimeForm.period.pm')));
      await tester.pump();
      await tester.tap(find.text('بحث'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('productionTimeForm.error')))
            .data,
        'هذا اليوم غير موجود في هذا الشهر',
      );
      expect(search.calls, 0);
    });

    testWidgets('no period chosen shows the Arabic error and never searches', (
      tester,
    ) async {
      final search = FakeRollSearchRepository(<RollSearchResult>[
        RollSearchSuccess(notFoundOutcome()),
      ]);
      await _pump(tester, search: search);
      await _type(tester, 'day', '30');
      await _type(tester, 'hour', '2');
      await _type(tester, 'minute', '05');
      await tester.tap(find.text('بحث'));
      await tester.pumpAndSettle();

      expect(find.text('اختر صباحاً أو مساء'), findsOneWidget);
      expect(search.calls, 0);
    });

    testWidgets('errors stay hidden until بحث is pressed', (tester) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(notFoundOutcome()),
        ]),
      );
      await _type(tester, 'hour', '13');
      expect(find.byKey(const Key('productionTimeForm.error')), findsNothing);
      await tester.tap(find.text('بحث'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('productionTimeForm.error')), findsOneWidget);
    });
  });

  group('search outcomes', () {
    testWidgets('sends the 24-hour factory minute to the repository', (
      tester,
    ) async {
      final search = FakeRollSearchRepository(<RollSearchResult>[
        RollSearchSuccess(notFoundOutcome()),
      ]);
      await _pump(tester, search: search);
      await _searchValid(tester);
      expect(search.queries, <Object>[kSearchQuery]);
    });

    testWidgets('exact match shows the roll, time, weight, state, verdict and '
        'mount button', (tester) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(foundOutcome(searchMatch())),
        ]),
      );
      await _searchValid(tester);

      expect(find.byKey(const Key('rollSearchMatchCard.$_rollNo')), findsOneWidget);
      expect(find.text(_rollNo), findsOneWidget);
      // 11:05:37Z is 14:05:37 in the factory (UTC+3 in September).
      expect(find.textContaining('30-09-2026'), findsWidgets);
      expect(find.textContaining('02:05:37 مساء'), findsOneWidget);
      expect(find.text('250.500 كغ'), findsOneWidget);
      expect(find.text('متاح'), findsOneWidget);
      expect(find.text('يمكن تركيب هذا الرول على هذا الخط'), findsOneWidget);
      expect(_mountButton, findsOneWidget);
      expect(find.text('تركيب الرول'), findsOneWidget);
    });

    testWidgets('no match shows the not-found message and nothing to mount', (
      tester,
    ) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(notFoundOutcome()),
        ]),
      );
      await _searchValid(tester);

      expect(find.text('لا يوجد رول مُنتَج في هذه الدقيقة'), findsOneWidget);
      expect(_mountButton, findsNothing);
    });

    testWidgets('a server ROLL_PRODUCTION_TIME_INVALID shows its Arabic text', (
      tester,
    ) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          const RollSearchFailure(
            BusinessFailure(
              code: ErrorCode.rollProductionTimeInvalid,
              details: <String, Object?>{
                'field': 'hour',
                'reason': 'OUT_OF_RANGE',
              },
            ),
          ),
        ]),
      );
      await _searchValid(tester);
      expect(find.text('قيمة الساعة غير صحيحة.'), findsOneWidget);
      expect(_mountButton, findsNothing);
    });

    testWidgets('a network failure shows the connectivity text', (
      tester,
    ) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          const RollSearchFailure(NetworkFailure()),
        ]),
      );
      await _searchValid(tester);
      expect(find.text(noConnectionArabic), findsOneWidget);
    });
  });

  group('multiple matches', () {
    final List<String> ids = <String>[
      '777000000001',
      '777000000002',
      '777000000003',
    ];

    FakeRollSearchRepository searchWithThree() =>
        FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(
            multipleOutcome(<RollSearchMatch>[
              for (int i = 0; i < ids.length; i++)
                searchMatch(
                  rollId: i + 1,
                  generatedRollId: ids[i],
                  producedWeightKg: 100.0 + i,
                ),
            ]),
          ),
        ]);

    testWidgets('lists every candidate, no card and no mount button until one '
        'is tapped', (tester) async {
      await _pump(tester, search: searchWithThree());
      await _searchValid(tester);

      expect(find.text('وُجد 3 رولات بنفس وقت الإنتاج. '
          'اختر الرول المطابق لرقم ووزن الملصق.'), findsOneWidget);
      for (final String id in ids) {
        expect(find.byKey(Key('rollSearchCandidate.$id')), findsOneWidget);
        expect(find.byKey(Key('rollSearchMatchCard.$id')), findsNothing);
      }
      expect(_mountButton, findsNothing);
    });

    testWidgets('tapping a candidate shows only that roll\'s card', (
      tester,
    ) async {
      await _pump(tester, search: searchWithThree());
      await _searchValid(tester);

      await tester.tap(find.byKey(const Key('rollSearchCandidate.777000000002')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('rollSearchMatchCard.777000000002')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('rollSearchMatchCard.777000000001')),
        findsNothing,
      );
      expect(_mountButton, findsOneWidget);
      expect(find.text('101.000 كغ'), findsWidgets);
    });

    testWidgets('mounting the chosen candidate mounts exactly that roll', (
      tester,
    ) async {
      final scan = FakeRollScanRepository(<RollScanResult>[
        RollScanSuccess(mountedRollFor('777000000003')),
      ]);
      await _pump(tester, search: searchWithThree(), scan: scan);
      await _searchValid(tester);

      await tester.tap(find.byKey(const Key('rollSearchCandidate.777000000003')));
      await tester.pumpAndSettle();
      await tester.tap(_mountButton);
      await tester.pumpAndSettle();

      expect(scan.mounts, hasLength(1));
      expect(scan.mounts.single.generatedRollId, '777000000003');
    });

    testWidgets('says when only the first rolls are listed', (tester) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(
            multipleOutcome(<RollSearchMatch>[
              searchMatch(rollId: 1, generatedRollId: '777000000001'),
              searchMatch(rollId: 2, generatedRollId: '777000000002'),
            ], matchCount: 14),
          ),
        ]),
      );
      await _searchValid(tester);
      expect(find.text('تظهر أول 2 رولات فقط.'), findsOneWidget);
    });
  });

  group('found but not mountable', () {
    testWidgets('ROLL_TYPE_NOT_ALLOWED_FOR_PRODUCT: no mount button, Arabic '
        'reason, no details button', (tester) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(
            foundOutcome(
              searchMatch(
                mountable: false,
                refusal: const BusinessFailure(
                  code: ErrorCode.rollTypeNotAllowedForProduct,
                ),
              ),
            ),
          ),
        ]),
      );
      await _searchValid(tester);

      expect(find.text('لا يمكن تركيب هذا الرول'), findsOneWidget);
      expect(
        find.byKey(const Key('rollSearchMatchCard.refusal')),
        findsOneWidget,
      );
      expect(
        find.text('نوع الرول غير مسموح للمنتج الحالي على هذا الخط.'),
        findsOneWidget,
      );
      expect(find.text('يمكن تركيب هذا الرول على هذا الخط'), findsNothing);
      expect(_mountButton, findsNothing);
      expect(find.text('عرض التفاصيل'), findsNothing);
    });

    testWidgets('ROLL_ALREADY_CONSUMED: «عرض التفاصيل» opens the existing '
        'blocked dialog', (tester) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(
            foundOutcome(
              searchMatch(
                mountable: false,
                refusal: const BusinessFailure(
                  code: ErrorCode.rollAlreadyConsumed,
                  details: <String, Object?>{
                    'rollNumber': _rollNo,
                    'workerName': 'محمد',
                  },
                ),
              ),
            ),
          ),
        ]),
      );
      await _searchValid(tester);

      expect(_mountButton, findsNothing);
      expect(find.text('هذا الرول مستهلك بالفعل.'), findsOneWidget);
      await tester.tap(find.text('عرض التفاصيل'));
      await tester.pumpAndSettle();

      expect(find.text('الرول مستهلك بالكامل'), findsOneWidget);
      expect(find.text('محمد'), findsOneWidget);

      await tester.tap(find.text('حسنًا'));
      await tester.pumpAndSettle();
      expect(find.text('الرول مستهلك بالكامل'), findsNothing);
      expect(_screen, findsOneWidget);
    });

    testWidgets('ROLL_CURING_MINIMUM_NOT_MET: details open the curing dialog', (
      tester,
    ) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(
            foundOutcome(
              searchMatch(
                mountable: false,
                refusal: const BusinessFailure(
                  code: ErrorCode.rollCuringMinimumNotMet,
                  details: <String, Object?>{
                    'minCuringHours': 48,
                    'actualAgeHours': 45,
                  },
                ),
              ),
            ),
          ),
        ]),
      );
      await _searchValid(tester);

      expect(_mountButton, findsNothing);
      await tester.tap(find.text('عرض التفاصيل'));
      await tester.pumpAndSettle();
      expect(find.text('لا يمكن تركيب الرول'), findsOneWidget);
      expect(find.text('الحد الأدنى المطلوب: 48 ساعة.'), findsOneWidget);
    });

    testWidgets('a non-mountable roll with no stated reason still offers no '
        'mount', (tester) async {
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(foundOutcome(searchMatch(mountable: false))),
        ]),
      );
      await _searchValid(tester);
      expect(find.text('لا يمكن تركيب هذا الرول'), findsOneWidget);
      expect(_mountButton, findsNothing);
    });
  });

  group('mounting from the preview uses the existing mount flow', () {
    testWidgets('success: one mountRoll call with the previewed roll, the '
        'screen pops and the success snackbar shows', (tester) async {
      final scan = FakeRollScanRepository(<RollScanResult>[
        RollScanSuccess(mountedRollFor(_rollNo)),
      ]);
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(foundOutcome(searchMatch())),
        ]),
        scan: scan,
      );
      await _searchValid(tester);

      await tester.tap(_mountButton);
      await tester.pumpAndSettle();

      expect(scan.mounts, hasLength(1));
      expect(scan.mounts.single.shiftLineId, kSearchShiftLineId);
      expect(scan.mounts.single.generatedRollId, _rollNo);
      expect(_screen, findsNothing);
      expect(find.byKey(const Key('host.open')), findsOneWidget);
      expect(find.text(_mountedSnack), findsOneWidget);
    });

    testWidgets('the shared scan controller ends in RollScanMounted', (
      tester,
    ) async {
      final scan = FakeRollScanRepository(<RollScanResult>[
        RollScanSuccess(mountedRollFor(_rollNo)),
      ]);
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(foundOutcome(searchMatch())),
        ]),
        scan: scan,
      );
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(_screen),
      );
      await _searchValid(tester);
      await tester.tap(_mountButton);
      await tester.pumpAndSettle();

      final RollScanState state = container.read(
        rollScanControllerProvider(kSearchShiftLineId),
      );
      expect(state, isA<RollScanMounted>());
      expect((state as RollScanMounted).roll.generatedRollId, _rollNo);
    });

    testWidgets('a curing-max warning shows the existing dialog, then the '
        'screen pops', (tester) async {
      final scan = FakeRollScanRepository(<RollScanResult>[
        RollScanSuccess(
          mountedRollFor(_rollNo),
          warnings: const <RollScanWarning>[
            RollScanWarning(
              code: 'ROLL_CURING_MAXIMUM_EXCEEDED',
              severity: 'WARNING',
              message: 'تنبيه: عمر هذا الرول تجاوز الحد الأعلى للحضانة.',
            ),
          ],
        ),
      ]);
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(foundOutcome(searchMatch())),
        ]),
        scan: scan,
      );
      await _searchValid(tester);
      await tester.tap(_mountButton);
      await tester.pumpAndSettle();

      expect(find.text('تنبيه — تجاوز الحضانة الأعلى'), findsOneWidget);
      expect(_screen, findsOneWidget);
      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(_screen, findsNothing);
      expect(scan.mounts, hasLength(1));
    });

    testWidgets('a refused mount shows the inline Arabic error, re-runs the '
        'search and clears the scan error', (tester) async {
      final scan = FakeRollScanRepository(<RollScanResult>[
        _scanFailure(ErrorCode.shiftLineAlreadyHasActiveRoll),
      ]);
      final search = FakeRollSearchRepository(<RollSearchResult>[
        RollSearchSuccess(foundOutcome(searchMatch())),
        RollSearchSuccess(
          foundOutcome(
            searchMatch(
              mountable: false,
              refusal: const BusinessFailure(
                code: ErrorCode.shiftLineAlreadyHasActiveRoll,
              ),
            ),
          ),
        ),
      ]);
      await _pump(tester, search: search, scan: scan);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(_screen),
      );
      await _searchValid(tester);
      expect(search.calls, 1);

      await tester.tap(_mountButton);
      await tester.pumpAndSettle();

      expect(scan.mounts, hasLength(1));
      expect(search.calls, 2);
      expect(search.queries.last, kSearchQuery);
      final String text = arabicForErrorCode(
        ErrorCode.shiftLineAlreadyHasActiveRoll,
      );
      // Once inline under the results, once as the refreshed preview's reason.
      expect(find.text(text), findsNWidgets(2));
      expect(_mountButton, findsNothing);
      expect(_screen, findsOneWidget);
      expect(find.text(_mountedSnack), findsNothing);
      expect(
        container.read(rollScanControllerProvider(kSearchShiftLineId)),
        isNot(isA<RollScanFailureState>()),
        reason: 'the scan screen must not inherit this refusal',
      );
    });

    testWidgets('a mount refused as consumed opens the blocked dialog and '
        'refreshes the preview', (tester) async {
      final scan = FakeRollScanRepository(<RollScanResult>[
        _scanFailure(
          ErrorCode.rollAlreadyConsumed,
          details: <String, Object?>{'workerName': 'خالد'},
        ),
      ]);
      final search = FakeRollSearchRepository(<RollSearchResult>[
        RollSearchSuccess(foundOutcome(searchMatch())),
        RollSearchSuccess(
          foundOutcome(
            searchMatch(
              mountable: false,
              refusal: const BusinessFailure(code: ErrorCode.rollAlreadyConsumed),
            ),
          ),
        ),
      ]);
      await _pump(tester, search: search, scan: scan);
      await _searchValid(tester);

      await tester.tap(_mountButton);
      await tester.pumpAndSettle();

      expect(find.text('الرول مستهلك بالكامل'), findsOneWidget);
      expect(find.text('خالد'), findsOneWidget);
      expect(search.calls, 2);
      await tester.tap(find.text('حسنًا'));
      await tester.pumpAndSettle();
      expect(_screen, findsOneWidget);
      expect(_mountButton, findsNothing);
    });

    testWidgets('a mount refused for curing opens the curing dialog', (
      tester,
    ) async {
      final scan = FakeRollScanRepository(<RollScanResult>[
        _scanFailure(
          ErrorCode.rollCuringMinimumNotMet,
          details: <String, Object?>{
            'minCuringHours': 48,
            'actualAgeHours': 45,
          },
        ),
      ]);
      await _pump(
        tester,
        search: FakeRollSearchRepository(<RollSearchResult>[
          RollSearchSuccess(foundOutcome(searchMatch())),
        ]),
        scan: scan,
      );
      await _searchValid(tester);
      await tester.tap(_mountButton);
      await tester.pumpAndSettle();

      expect(find.text('لا يمكن تركيب الرول'), findsOneWidget);
      expect(find.text('العمر الحالي: 45 ساعة.'), findsOneWidget);
    });

    testWidgets('a device-key fault during the mount is shown inline and refreshes the preview', (
      tester,
    ) async {
      final scan = FakeRollScanRepository(<RollScanResult>[
        _scanFailure(ErrorCode.authInvalidCredentials),
      ]);
      final search = FakeRollSearchRepository(<RollSearchResult>[
        RollSearchSuccess(foundOutcome(searchMatch())),
      ]);
      await _pump(tester, search: search, scan: scan);
      await _searchValid(tester);
      await tester.tap(_mountButton);
      await tester.pumpAndSettle();
      // A device-key fault is not a session loss, so it refreshes and shows
      // the inline text instead of a dialog.
      expect(search.calls, 2);
      expect(
        find.text(arabicForErrorCode(ErrorCode.authInvalidCredentials)),
        findsOneWidget,
      );
    });
  });
}
