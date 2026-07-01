import 'package:flutter_test/flutter_test.dart';
import 'package:mensaena/services/weather_service.dart';

void main() {
  group('WeatherDay', () {
    test('emoji for clear sky', () {
      final d = WeatherDay(
        date: _epoch,
        tempMin: 10,
        tempMax: 20,
        code: 0,
        precipitationMm: 0,
      );
      expect(d.emoji, '☀️');
    });

    test('emoji for thunderstorm', () {
      final d = WeatherDay(
        date: _epoch,
        tempMin: 12,
        tempMax: 18,
        code: 95,
        precipitationMm: 5,
      );
      expect(d.emoji, '⛈️');
    });

    test('labelKey for snow', () {
      final d = WeatherDay(
        date: _epoch,
        tempMin: -2,
        tempMax: 1,
        code: 71,
        precipitationMm: 3,
      );
      expect(d.labelKey, 'weather.condSnow');
    });

    test('labelKey for fog', () {
      final d = WeatherDay(
        date: _epoch,
        tempMin: 5,
        tempMax: 9,
        code: 45,
        precipitationMm: 0,
      );
      expect(d.labelKey, 'weather.condFog');
    });
  });

  group('WeatherNow', () {
    WeatherNow now(int code) => WeatherNow(
          code: code,
          tempC: 17.4,
          precipitationMm: 0,
          rainMm: 0,
          showersMm: 0,
          snowfallCm: 0,
          cloudCoverPct: 0,
          windKmh: 5,
          isDay: true,
        );

    test('emoji for clear sky', () {
      expect(now(0).emoji, '☀️');
    });

    test('emoji for thunderstorm', () {
      expect(now(95).emoji, '⛈️');
    });

    test('labelKey for rain', () {
      expect(now(63).labelKey, 'weather.condRain');
    });

    test('labelKey unknown fallback', () {
      // Code 40 fällt durch alle WMO-Bereiche → Unbekannt.
      expect(now(40).labelKey, 'weather.condUnknown');
    });
  });

  group('AirQuality', () {
    test('aqiLabelKey good', () {
      const aq = AirQuality(pm25: 3, pm10: 8, europeanAqi: 15);
      expect(aq.aqiLabelKey, 'weather.aqGood');
    });

    test('aqiLabelKey moderate', () {
      const aq = AirQuality(pm25: 15, pm10: 30, europeanAqi: 55);
      expect(aq.aqiLabelKey, 'weather.aqModerate');
    });

    test('aqiLabelKey veryPoor', () {
      const aq = AirQuality(pm25: 50, pm10: 90, europeanAqi: 95);
      expect(aq.aqiLabelKey, 'weather.aqVeryPoor');
    });

    test('aqiColor green for good air', () {
      const aq = AirQuality(pm25: 2, pm10: 5, europeanAqi: 10);
      expect(aq.aqiColor.value, 0xFF4CAF50);
    });
  });

  group('WeatherService.clearCache', () {
    test('does not throw', () {
      expect(() => WeatherService.clearCache(), returnsNormally);
    });
  });
}

final _epoch = DateTime.utc(2026, 1, 1);
