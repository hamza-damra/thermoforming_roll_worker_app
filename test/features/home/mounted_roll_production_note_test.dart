import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/theme/app_colors.dart';
import 'package:thermoforming_roll_worker/core/theme/app_theme.dart';
import 'package:thermoforming_roll_worker/features/home/data/dto/shift_line_summary_response.dart';
import 'package:thermoforming_roll_worker/features/home/data/shift_line_summary_providers.dart';
import 'package:thermoforming_roll_worker/features/home/domain/entities/shift_line_summary.dart';
import 'package:thermoforming_roll_worker/features/home/domain/shift_line_summary_repository.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/controllers/shift_line_summary_controller.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/controllers/shift_line_summary_state.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/screens/roll_worker_home_screen.dart';
import 'package:thermoforming_roll_worker/features/home/presentation/widgets/mounted_roll_note_card.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/data/roll_worker_auth_providers.dart';
import 'package:thermoforming_roll_worker/features/roll_worker_auth/domain/roll_worker_auth_repository.dart';

class _MockSummaryRepo extends Mock implements ShiftLineSummaryRepository {}

class _MockAuthRepo extends Mock implements RollWorkerAuthRepository {}

const int _shiftLineId = 815;
const String _note = 'الطرف الأيمن فيه تموج خفيف';
const String _multiLineNote = 'السطر الأول من الملاحظة\nالسطر الثاني من الملاحظة';

Map<String, dynamic> _mountedJson({Object? note, bool includeNote = true}) =>
    <String, dynamic>{
      'consumptionItemId': 123,
      'rollId': 9876,
      'generatedRollId': '101000004321',
      'rollTypeCode': 'TP-1',
      'rollTypeName': 'شفاف 0.65',
      'lastKnownWeightKg': 45.2,
      if (includeNote) 'productionNote': note,
    };

SummaryMountedRoll _roll({
  int rollId = 9876,
  String generatedRollId = '101000004321',
  String? note,
}) => SummaryMountedRoll(
  consumptionItemId: rollId + 1,
  rollId: rollId,
  generatedRollId: generatedRollId,
  rollTypeCode: 'TP-1',
  rollTypeName: 'شفاف 0.65',
  lastKnownWeightKg: 45.2,
  productionNote: note,
);

ShiftLineSummary _summary({SummaryMountedRoll? mountedRoll}) =>
    ShiftLineSummary(
      shiftLineId: _shiftLineId,
      thermoformingLineCode: 'TH-01',
      thermoformingLineName: 'خط التشكيل 1',
      completedRollsInSession: 2,
      completedRollsByCurrentWorker: 2,
      mountedRoll: mountedRoll,
      activeOperatorName: 'مشغل التشكيل',
    );

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrapHome(_MockSummaryRepo summaryRepo) => ProviderScope(
  overrides: <Override>[
    shiftLineSummaryRepositoryProvider.overrideWithValue(summaryRepo),
    rollWorkerAuthRepositoryProvider.overrideWithValue(_MockAuthRepo()),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const RollWorkerHomeScreen(shiftLineId: _shiftLineId),
  ),
);

Future<void> _pumpHome(WidgetTester tester, SummaryMountedRoll? roll) async {
  _useTallSurface(tester);
  final _MockSummaryRepo repo = _MockSummaryRepo();
  when(
    () => repo.fetchSummary(shiftLineId: _shiftLineId),
  ).thenAnswer((_) async => SummarySuccess(_summary(mountedRoll: roll)));
  await tester.pumpWidget(_wrapHome(repo));
  await tester.pumpAndSettle();
}

void main() {
  group('SummaryMountedRollResponse.productionNote (V215)', () {
    test('parses the note when present, keeping line breaks', () {
      final SummaryMountedRoll roll = SummaryMountedRollResponse.fromJson(
        _mountedJson(note: _multiLineNote),
      ).toEntity();
      expect(roll.productionNote, _multiLineNote);
      expect(roll.visibleProductionNote, _multiLineNote);
    });

    test('absent and null both parse to no note', () {
      final SummaryMountedRoll absent = SummaryMountedRollResponse.fromJson(
        _mountedJson(includeNote: false),
      ).toEntity();
      final SummaryMountedRoll explicitNull =
          SummaryMountedRollResponse.fromJson(_mountedJson()).toEntity();
      expect(absent.productionNote, isNull);
      expect(explicitNull.productionNote, isNull);
      expect(absent.visibleProductionNote, isNull);
    });

    test('blank note is hidden defensively', () {
      expect(_roll(note: '   \n ').visibleProductionNote, isNull);
      expect(_roll(note: '  $_note ').visibleProductionNote, _note);
    });

    test('copyWith (SSE weight update) preserves the note', () {
      final SummaryMountedRoll updated = _roll(
        note: _note,
      ).copyWith(lastKnownWeightKg: 30.0);
      expect(updated.productionNote, _note);
      expect(updated.lastKnownWeightKg, 30.0);
    });
  });

  group('controller: note follows the mounted roll', () {
    test('switches with the mounted roll and disappears when unmounted', () async {
      final _MockSummaryRepo repo = _MockSummaryRepo();
      final _MockAuthRepo authRepo = _MockAuthRepo();
      when(() => authRepo.clearStoredToken(any())).thenAnswer((_) async {});
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          shiftLineSummaryRepositoryProvider.overrideWithValue(repo),
          rollWorkerAuthRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);
      final ShiftLineSummaryController notifier = container.read(
        shiftLineSummaryControllerProvider(_shiftLineId).notifier,
      );
      String? currentNote() {
        final ShiftLineSummaryState s = container.read(
          shiftLineSummaryControllerProvider(_shiftLineId),
        );
        return (s as SummaryLoaded).summary.mountedRoll?.visibleProductionNote;
      }

      when(() => repo.fetchSummary(shiftLineId: _shiftLineId)).thenAnswer(
        (_) async => SummarySuccess(_summary(mountedRoll: _roll(note: _note))),
      );
      await notifier.load();
      expect(currentNote(), _note);

      // A different roll without a note: the previous note must not linger.
      when(() => repo.fetchSummary(shiftLineId: _shiftLineId)).thenAnswer(
        (_) async => SummarySuccess(
          _summary(mountedRoll: _roll(rollId: 1111, generatedRollId: '1')),
        ),
      );
      await notifier.refresh();
      expect(currentNote(), isNull);

      // Nothing mounted.
      when(
        () => repo.fetchSummary(shiftLineId: _shiftLineId),
      ).thenAnswer((_) async => SummarySuccess(_summary()));
      await notifier.refresh();
      final ShiftLineSummaryState s = container.read(
        shiftLineSummaryControllerProvider(_shiftLineId),
      );
      expect((s as SummaryLoaded).summary.mountedRoll, isNull);
    });
  });

  group('home screen note card', () {
    testWidgets('shows title and full multi-line RTL text under the roll card', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, _roll(note: _multiLineNote));

      expect(find.byType(MountedRollNoteCard), findsOneWidget);
      expect(find.text(MountedRollNoteCard.title), findsOneWidget);
      final Text body = tester.widget<Text>(find.text(_multiLineNote));
      expect(body.textDirection, TextDirection.rtl);
      expect(body.maxLines, isNull);
      expect(body.overflow, isNot(TextOverflow.ellipsis));
      // Sits below the mounted-roll card.
      expect(
        tester.getTopLeft(find.text(MountedRollNoteCard.title)).dy,
        greaterThan(tester.getTopLeft(find.text('الرول المركب حالياً')).dy),
      );
      // Not styled as an error.
      expect(body.style?.color, isNot(AppColors.error));
      expect(find.byIcon(Icons.error_outline), findsNothing);
      // Roll actions stay available.
      final Finder close = find.text(RollWorkerHomeScreen.closeCurrentRoll);
      expect(close, findsOneWidget);
      final ButtonStyleButton button = tester.widget<ButtonStyleButton>(
        find.ancestor(of: close, matching: find.bySubtype<ButtonStyleButton>()),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('no card when the note is null', (WidgetTester tester) async {
      await _pumpHome(tester, _roll());
      expect(find.byType(MountedRollNoteCard), findsNothing);
      expect(find.text(MountedRollNoteCard.title), findsNothing);
    });

    testWidgets('no card when the note is blank', (WidgetTester tester) async {
      await _pumpHome(tester, _roll(note: '  \n  '));
      expect(find.byType(MountedRollNoteCard), findsNothing);
    });

    testWidgets('no card when nothing is mounted', (WidgetTester tester) async {
      await _pumpHome(tester, null);
      expect(find.byType(MountedRollNoteCard), findsNothing);
    });

    testWidgets('500-char note wraps without overflow on a phone width', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final String longNote = List<String>.filled(100, 'تموج').join(' ');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Material(
              child: SingleChildScrollView(
                child: MountedRollNoteCard(note: longNote),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(longNote), findsOneWidget);
    });
  });
}
