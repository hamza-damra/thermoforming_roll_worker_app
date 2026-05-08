import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/storage/secure_token_storage.dart';
import 'package:thermoforming_roll_worker/core/storage/storage_keys.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('StorageKeys', () {
    test('rollWorkerSessionToken key includes shiftLineId', () {
      expect(
        StorageKeys.rollWorkerSessionToken(800),
        'roll_worker_session_token_800',
      );
    });

    test('different shiftLineIds get different keys (no collisions)', () {
      expect(
        StorageKeys.rollWorkerSessionToken(800),
        isNot(StorageKeys.rollWorkerSessionToken(801)),
      );
    });
  });

  group('SecureTokenStorage', () {
    late _MockSecureStorage mock;
    late SecureTokenStorage storage;

    setUp(() {
      mock = _MockSecureStorage();
      storage = SecureTokenStorage.withStorage(mock);
    });

    test('writeSessionToken writes under per-shiftLineId key', () async {
      when(
        () => mock.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await storage.writeSessionToken(shiftLineId: 800, token: 'raw');

      verify(
        () => mock.write(key: 'roll_worker_session_token_800', value: 'raw'),
      ).called(1);
    });

    test('writeSessionToken rejects empty token', () async {
      expect(
        () => storage.writeSessionToken(shiftLineId: 800, token: ''),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(
        () => mock.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      );
    });

    test('readSessionToken reads from per-shiftLineId key', () async {
      when(
        () => mock.read(key: 'roll_worker_session_token_800'),
      ).thenAnswer((_) async => 'stored-token');

      final String? got = await storage.readSessionToken(800);

      expect(got, 'stored-token');
    });

    test('clearSessionToken deletes per-shiftLineId key', () async {
      when(() => mock.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      await storage.clearSessionToken(800);

      verify(() => mock.delete(key: 'roll_worker_session_token_800')).called(1);
    });

    test('clearing one shift-line does not touch another', () async {
      when(() => mock.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      await storage.clearSessionToken(800);

      verifyNever(() => mock.delete(key: 'roll_worker_session_token_801'));
    });

    test('readSelectedShiftLineId parses integer or returns null', () async {
      when(
        () => mock.read(key: StorageKeys.selectedShiftLineId),
      ).thenAnswer((_) async => '800');
      expect(await storage.readSelectedShiftLineId(), 800);

      when(
        () => mock.read(key: StorageKeys.selectedShiftLineId),
      ).thenAnswer((_) async => null);
      expect(await storage.readSelectedShiftLineId(), isNull);

      when(
        () => mock.read(key: StorageKeys.selectedShiftLineId),
      ).thenAnswer((_) async => 'not-a-number');
      expect(await storage.readSelectedShiftLineId(), isNull);
    });
  });
}
