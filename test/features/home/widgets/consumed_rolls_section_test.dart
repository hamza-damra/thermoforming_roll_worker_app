import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/consumed_rolls_section.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  builder: (context, body) => Directionality(
    textDirection: TextDirection.rtl,
    child: Material(child: body ?? const SizedBox.shrink()),
  ),
  home: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: child,
  ),
);

ConsumedRoll _roll({
  int id = 900,
  String generatedRollId = '001000000123',
  String rollTypeCode = 'TP-1',
  String rollTypeName = 'White',
  double startWeightKg = 200.0,
  double consumedWeightKg = 200.0,
  double endWeightKg = 0.0,
  double? remainingWeightKg,
  String closedReason = 'FULL_CONSUMPTION',
  String remainderAction = 'NONE',
  String endedAtDisplay = '23 أيار، 10:00 ص',
  bool? reprintAvailable,
  String? reprintLabelType,
  DateTime? labelTimestamp,
}) => ConsumedRoll(
  consumptionItemId: id,
  rollId: id + 1000,
  generatedRollId: generatedRollId,
  rollTypeCode: rollTypeCode,
  rollTypeName: rollTypeName,
  startWeightKg: startWeightKg,
  endWeightKg: endWeightKg,
  consumedWeightKg: consumedWeightKg,
  remainingWeightKg: remainingWeightKg,
  closedReason: closedReason,
  remainderAction: remainderAction,
  endedAt: DateTime.utc(2026, 5, 23, 10),
  endedAtDisplay: endedAtDisplay,
  reprintAvailable: reprintAvailable,
  reprintLabelType: reprintLabelType,
  labelTimestamp: labelTimestamp,
);

/// Tap the visible header of the (only) consumed-roll card to expand it.
Future<void> _expandFirstCard(WidgetTester tester) async {
  // Tap the chevron icon — guaranteed to live inside the card's tap target.
  await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders header and empty-state copy when list is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ConsumedRollsSection(rolls: <ConsumedRoll>[])),
    );

    expect(find.text('الرولات المستهلكة في هذه الجلسة'), findsOneWidget);
    expect(
      find.text('لا توجد رولات مستهلكة في هذه الجلسة'),
      findsOneWidget,
    );
  });

  testWidgets('cards start collapsed — full info rows are hidden by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ConsumedRollsSection(
          rolls: <ConsumedRoll>[_roll(remainingWeightKg: 30.0)],
        ),
      ),
    );

    // The compact strip's close-reason chip is always visible.
    expect(find.text('استهلاك كامل'), findsOneWidget);
    // Expanded-only info rows are hidden until the worker taps to expand.
    expect(find.text('الوزن الابتدائي'), findsNothing);
    expect(find.text('الوزن المتبقي'), findsNothing);
    expect(find.text('سبب الإغلاق'), findsNothing);
    expect(find.text('إجراء المتبقي'), findsNothing);
  });

  testWidgets('expanded card reveals full Arabic info rows', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ConsumedRollsSection(
          rolls: <ConsumedRoll>[
            _roll(
              closedReason: 'PARTIAL_RETURN',
              remainderAction: 'RETURN',
              remainingWeightKg: 30.0,
            ),
          ],
        ),
      ),
    );

    await _expandFirstCard(tester);

    expect(find.text('الوزن الابتدائي'), findsOneWidget);
    expect(find.text('الوزن المتبقي'), findsOneWidget);
    expect(find.text('سبب الإغلاق'), findsOneWidget);
    expect(find.text('إجراء المتبقي'), findsOneWidget);
    // Wire-code → Arabic label mapping is rendered inside the body.
    expect(find.text('إرجاع المتبقي'), findsOneWidget);
  });

  testWidgets(
    'collapsed compact-strip maps each closedReason to its Arabic label',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          ConsumedRollsSection(
            rolls: <ConsumedRoll>[
              _roll(),
              _roll(
                id: 901,
                generatedRollId: '001000000124',
                consumedWeightKg: 170.0,
                endWeightKg: 30.0,
                remainingWeightKg: 30.0,
                closedReason: 'PARTIAL_RETURN',
                remainderAction: 'RETURN',
              ),
              _roll(
                id: 902,
                generatedRollId: '001000000125',
                consumedWeightKg: 150.0,
                endWeightKg: 50.0,
                remainingWeightKg: 50.0,
                closedReason: 'PARTIAL_GRINDING',
                remainderAction: 'GRINDING',
              ),
            ],
          ),
        ),
      );

      expect(find.text('استهلاك كامل'), findsOneWidget);
      expect(find.text('إرجاع جزئي'), findsOneWidget);
      expect(find.text('جرش جزئي'), findsOneWidget);
    },
  );

  testWidgets('renders endedAtDisplay verbatim (no re-formatting)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ConsumedRollsSection(
          rolls: <ConsumedRoll>[_roll(endedAtDisplay: '23 أيار، 10:00 ص')],
        ),
      ),
    );

    expect(find.text('23 أيار، 10:00 ص'), findsOneWidget);
  });

  testWidgets('hides remaining-weight row when remainingWeightKg is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ConsumedRollsSection(rolls: <ConsumedRoll>[_roll()])),
    );

    await _expandFirstCard(tester);
    expect(find.text('الوزن المتبقي'), findsNothing);
  });

  testWidgets('shows remaining-weight row when remainingWeightKg is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ConsumedRollsSection(
          rolls: <ConsumedRoll>[_roll(remainingWeightKg: 30.0)],
        ),
      ),
    );

    await _expandFirstCard(tester);
    expect(find.text('الوزن المتبقي'), findsOneWidget);
    expect(find.text('30.000 كغ'), findsOneWidget);
  });

  testWidgets('falls back to raw wire code when unknown', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ConsumedRollsSection(
          rolls: <ConsumedRoll>[
            _roll(closedReason: 'SOMETHING_NEW', remainderAction: 'OTHER'),
          ],
        ),
      ),
    );

    // Compact strip shows the (unknown) closedReason verbatim.
    expect(find.text('SOMETHING_NEW'), findsOneWidget);

    // remainderAction is only visible in the expanded body.
    await _expandFirstCard(tester);
    expect(find.text('OTHER'), findsOneWidget);
  });

  group('reprint visibility (RETURN / GRINDING only)', () {
    testWidgets('FULL_CONSUMPTION + NONE → no reprint button or icon',
        (tester) async {
      bool fired = false;
      await tester.pumpWidget(
        _wrap(
          ConsumedRollsSection(
            rolls: <ConsumedRoll>[_roll()],
            onReprint: (_) => fired = true,
          ),
        ),
      );

      // Collapsed: no inline print icon.
      expect(find.byIcon(Icons.print_outlined), findsNothing);

      await _expandFirstCard(tester);
      // Expanded: no full reprint button either.
      expect(find.text('إعادة طباعة الليبل'), findsNothing);
      expect(fired, isFalse);
    });

    testWidgets('RETURN → inline icon (collapsed) + full button (expanded)',
        (tester) async {
      String? receivedId;
      await tester.pumpWidget(
        _wrap(
          ConsumedRollsSection(
            rolls: <ConsumedRoll>[
              _roll(
                closedReason: 'PARTIAL_RETURN',
                remainderAction: 'RETURN',
                remainingWeightKg: 30.0,
              ),
            ],
            onReprint: (String id) => receivedId = id,
          ),
        ),
      );

      expect(find.byIcon(Icons.print_outlined), findsOneWidget);

      await _expandFirstCard(tester);
      expect(find.text('إعادة طباعة الليبل'), findsOneWidget);

      await tester.tap(find.text('إعادة طباعة الليبل'));
      await tester.pumpAndSettle();
      expect(receivedId, '001000000123');
    });

    testWidgets('GRINDING → inline icon (collapsed) + full button (expanded)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ConsumedRollsSection(
            rolls: <ConsumedRoll>[
              _roll(
                closedReason: 'PARTIAL_GRINDING',
                remainderAction: 'GRINDING',
                remainingWeightKg: 50.0,
              ),
            ],
            onReprint: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.print_outlined), findsOneWidget);

      await _expandFirstCard(tester);
      expect(find.text('إعادة طباعة الليبل'), findsOneWidget);
    });

    testWidgets('RETURN with remainingWeightKg == 0 → reprint hidden',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ConsumedRollsSection(
            rolls: <ConsumedRoll>[
              _roll(
                closedReason: 'PARTIAL_RETURN',
                remainderAction: 'RETURN',
                remainingWeightKg: 0.0,
              ),
            ],
            onReprint: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.print_outlined), findsNothing);
      await _expandFirstCard(tester);
      expect(find.text('إعادة طباعة الليبل'), findsNothing);
    });

    testWidgets('onReprint == null → no reprint affordance even on RETURN',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          ConsumedRollsSection(
            rolls: <ConsumedRoll>[
              _roll(
                closedReason: 'PARTIAL_RETURN',
                remainderAction: 'RETURN',
                remainingWeightKg: 30.0,
              ),
            ],
            // onReprint omitted ⇒ disabled
          ),
        ),
      );

      expect(find.byIcon(Icons.print_outlined), findsNothing);
      await _expandFirstCard(tester);
      expect(find.text('إعادة طباعة الليبل'), findsNothing);
    });
  });

  group('reprint gating uses backend reprintAvailable when present', () {
    testWidgets(
      'reprintAvailable=true wins over a FULL_CONSUMPTION remainderAction',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ConsumedRollsSection(
              rolls: <ConsumedRoll>[
                _roll(
                  // Backend says reprint, despite the row otherwise looking
                  // like a fully-consumed roll.
                  reprintAvailable: true,
                ),
              ],
              onReprint: (_) {},
            ),
          ),
        );

        expect(find.byIcon(Icons.print_outlined), findsOneWidget);
        await _expandFirstCard(tester);
        expect(find.text('إعادة طباعة الليبل'), findsOneWidget);
      },
    );

    testWidgets(
      'reprintAvailable=false wins over a RETURN remainderAction',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ConsumedRollsSection(
              rolls: <ConsumedRoll>[
                _roll(
                  closedReason: 'PARTIAL_RETURN',
                  remainderAction: 'RETURN',
                  remainingWeightKg: 30.0,
                  reprintAvailable: false,
                ),
              ],
              onReprint: (_) {},
            ),
          ),
        );

        expect(find.byIcon(Icons.print_outlined), findsNothing);
        await _expandFirstCard(tester);
        expect(find.text('إعادة طباعة الليبل'), findsNothing);
      },
    );

    testWidgets(
      'reprintAvailable=null (older backend) falls back to legacy inference',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ConsumedRollsSection(
              rolls: <ConsumedRoll>[
                _roll(
                  closedReason: 'PARTIAL_RETURN',
                  remainderAction: 'RETURN',
                  remainingWeightKg: 30.0,
                  // reprintAvailable: null  ⇒ inference path
                ),
              ],
              onReprint: (_) {},
            ),
          ),
        );

        // Inference path: RETURN + remaining > 0 → show reprint.
        expect(find.byIcon(Icons.print_outlined), findsOneWidget);
      },
    );
  });
}
