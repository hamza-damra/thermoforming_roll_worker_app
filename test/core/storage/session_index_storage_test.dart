import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thermoforming_roll_worker/core/storage/session_index_storage.dart';

class _MockRaw extends Mock implements FlutterSecureStorage {}

const String _key = 'roll_worker_active_shift_line_ids';

void main() {
  late _MockRaw raw;
  late SessionIndexStorage storage;

  setUp(() {
    raw = _MockRaw();
    storage = SessionIndexStorage.withStorage(raw);
  });

  test('readIds returns empty set when key absent', () async {
    when(() => raw.read(key: _key)).thenAnswer((_) async => null);
    expect(await storage.readIds(), <int>{});
  });

  test('readIds parses a JSON list of ints', () async {
    when(() => raw.read(key: _key)).thenAnswer((_) async => '[101,102]');
    expect(await storage.readIds(), <int>{101, 102});
  });

  test('readIds is tolerant of malformed JSON (returns empty set)', () async {
    when(() => raw.read(key: _key)).thenAnswer((_) async => 'not json');
    expect(await storage.readIds(), <int>{});
  });

  test('writeIds encodes and persists', () async {
    when(
      () => raw.write(
        key: _key,
        value: any<String>(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    await storage.writeIds(<int>{101, 102});

    final captured = verify(
      () => raw.write(key: _key, value: captureAny<String>(named: 'value')),
    ).captured.single as String;
    // The set order isn't guaranteed by JSON output, just check membership.
    expect(captured.contains('101') && captured.contains('102'), isTrue);
  });

  test('clear deletes the key', () async {
    when(() => raw.delete(key: _key)).thenAnswer((_) async {});
    await storage.clear();
    verify(() => raw.delete(key: _key)).called(1);
  });
}
