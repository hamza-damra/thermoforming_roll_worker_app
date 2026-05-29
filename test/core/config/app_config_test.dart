import 'package:flutter_test/flutter_test.dart';
import 'package:thermoforming_roll_worker/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('isMissing when both fields empty', () {
      final config = AppConfig(apiBaseUrl: '', deviceKey: '');
      expect(config.isMissing, isTrue);
      expect(config.isComplete, isFalse);
    });

    test('isMissing when API base url is empty', () {
      final config = AppConfig(apiBaseUrl: '', deviceKey: 'k');
      expect(config.isMissing, isTrue);
    });

    test('isMissing when device key is empty', () {
      final config = AppConfig(apiBaseUrl: 'https://x', deviceKey: '');
      expect(config.isMissing, isTrue);
    });

    test('isComplete when both fields present', () {
      final config = AppConfig(
        apiBaseUrl: 'https://api.taleeb.ps',
        deviceKey: 'k',
      );
      expect(config.isComplete, isTrue);
      expect(config.isMissing, isFalse);
    });

    test('toString never includes the device key', () {
      final config = AppConfig(
        apiBaseUrl: 'https://api.taleeb.ps',
        deviceKey: 'super-secret-device-key-12345',
      );
      final String s = config.toString();
      expect(s, contains('https://api.taleeb.ps'));
      expect(s, contains('<redacted>'));
      expect(s, isNot(contains('super-secret-device-key-12345')));
    });

    test('missingConfigMessage is the prescribed Arabic copy', () {
      expect(
        AppConfig.missingConfigMessage,
        'إعدادات التطبيق غير مكتملة، يرجى التواصل مع المسؤول',
      );
    });
  });
}
