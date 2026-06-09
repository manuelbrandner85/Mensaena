import 'dart:convert';

import 'package:http/http.dart' as http;

/// SKILL: mensaena-features
/// Open-Meteo Wetter-API — kostenlos, kein API-Key. Pendant zu
/// `src/lib/weather.ts` der Web-App.
class WeatherService {
  const WeatherService._();

  /// 5-Tages-Vorhersage. Liefert leere Liste bei Fehler.
  static Future<List<WeatherDay>> forecast({
    required double latitude,
    required double longitude,
    int days = 5,
    String timezone = 'Europe/Berlin',
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'daily':
          'temperature_2m_max,temperature_2m_min,weathercode,precipitation_sum',
      'timezone': timezone,
      'forecast_days': '$days',
    });
    try {
      final res =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return const [];
      final dates = (daily['time'] as List).cast<String>();
      final tmax = (daily['temperature_2m_max'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final tmin = (daily['temperature_2m_min'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final codes = (daily['weathercode'] as List)
          .map((e) => (e as num).toInt())
          .toList();
      final precip = (daily['precipitation_sum'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final out = <WeatherDay>[];
      for (var i = 0; i < dates.length; i++) {
        out.add(WeatherDay(
          date: DateTime.parse(dates[i]).toUtc(),
          tempMin: tmin[i],
          tempMax: tmax[i],
          code: codes[i],
          precipitationMm: precip[i],
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.code,
    required this.precipitationMm,
  });

  final DateTime date;
  final double tempMin;
  final double tempMax;
  final int code;
  final double precipitationMm;

  /// WMO-Code → Emoji (Pendant zu Web `weatherCodeToEmoji`).
  String get emoji {
    if (code == 0) return '☀️';
    if (code == 1 || code == 2) return '🌤️';
    if (code == 3) return '☁️';
    if (code == 45 || code == 48) return '🌫️';
    if (code >= 51 && code <= 57) return '🌦️';
    if (code >= 61 && code <= 67) return '🌧️';
    if (code >= 71 && code <= 77) return '❄️';
    if (code >= 80 && code <= 82) return '🌧️';
    if (code >= 95) return '⛈️';
    return '🌡️';
  }

  String get label {
    if (code == 0) return 'Klar';
    if (code <= 2) return 'Sonnig';
    if (code == 3) return 'Bewölkt';
    if (code == 45 || code == 48) return 'Nebel';
    if (code >= 51 && code <= 57) return 'Niesel';
    if (code >= 61 && code <= 67) return 'Regen';
    if (code >= 71 && code <= 77) return 'Schnee';
    if (code >= 80 && code <= 82) return 'Schauer';
    if (code >= 95) return 'Gewitter';
    return '';
  }
}
