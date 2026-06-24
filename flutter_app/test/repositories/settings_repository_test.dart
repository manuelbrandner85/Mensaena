import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/repositories/settings_repository.dart';

void main() {
  group('SettingsRepository.parseLiveWeatherBackground', () {
    test('null map → null (Nutzer hat nie gewählt)', () {
      expect(SettingsRepository.parseLiveWeatherBackground(null), isNull);
    });

    test('Key fehlt → null (kein Default-Override, Migration möglich)', () {
      expect(
        SettingsRepository.parseLiveWeatherBackground(
            <String, dynamic>{'other': true}),
        isNull,
      );
    });

    test('Key true → true', () {
      expect(
        SettingsRepository.parseLiveWeatherBackground(
            <String, dynamic>{'live_weather_background': true}),
        isTrue,
      );
    });

    test('Key false bleibt erhalten (kein versehentliches Anschalten)', () {
      expect(
        SettingsRepository.parseLiveWeatherBackground(
            <String, dynamic>{'live_weather_background': false}),
        isFalse,
      );
    });

    test('Nicht-bool-Wert → false (defensiv)', () {
      expect(
        SettingsRepository.parseLiveWeatherBackground(
            <String, dynamic>{'live_weather_background': 'yes'}),
        isFalse,
      );
    });
  });
}
