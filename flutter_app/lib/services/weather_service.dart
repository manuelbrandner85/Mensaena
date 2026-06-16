import 'dart:convert';

import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;

/// SKILL: mensaena-features
/// Open-Meteo Wetter-API — kostenlos, kein API-Key. Pendant zu
/// `src/lib/weather.ts` der Web-App.
///
/// Erweiterung (Weather-Modul): Stündliche Daten + Luftqualität + 30-Min-Cache.
class WeatherService {
  const WeatherService._();

  // ── 30-Minuten In-Memory Cache ────────────────────────────────────────────

  static final Map<String, _CacheEntry<List<WeatherDay>>> _forecastCache = {};
  static final Map<String, _CacheEntry<List<WeatherHourly>>> _hourlyCache = {};
  static final Map<String, _CacheEntry<AirQuality?>> _aqCache = {};

  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';

  /// 5-Tages-Vorhersage (täglich). Cached 30 Minuten.
  static Future<List<WeatherDay>> forecast({
    required double latitude,
    required double longitude,
    int days = 5,
    String timezone = 'Europe/Berlin',
  }) async {
    final key = _key(latitude, longitude);
    final cached = _forecastCache[key];
    if (cached != null && !cached.isExpired) return cached.data;

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'daily':
          'temperature_2m_max,temperature_2m_min,weathercode,precipitation_sum',
      'timezone': timezone,
      'forecast_days': '$days',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return cached?.data ?? const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return cached?.data ?? const [];
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
      _forecastCache[key] = _CacheEntry(out);
      return out;
    } catch (_) {
      return cached?.data ?? const [];
    }
  }

  /// Stündliche Temperatur für die nächsten 24 h. Cached 30 Minuten.
  static Future<List<WeatherHourly>> hourly({
    required double latitude,
    required double longitude,
    String timezone = 'Europe/Berlin',
  }) async {
    final key = _key(latitude, longitude);
    final cached = _hourlyCache[key];
    if (cached != null && !cached.isExpired) return cached.data;

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'hourly': 'temperature_2m,relativehumidity_2m,weathercode',
      'timezone': timezone,
      'forecast_days': '2',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return cached?.data ?? const [];
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final h = json['hourly'] as Map<String, dynamic>?;
      if (h == null) return cached?.data ?? const [];
      final times = (h['time'] as List).cast<String>();
      final temps = (h['temperature_2m'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final humidity = (h['relativehumidity_2m'] as List)
          .map((e) => (e as num).toInt())
          .toList();
      final codes = (h['weathercode'] as List)
          .map((e) => (e as num).toInt())
          .toList();
      final now = DateTime.now();
      final out = <WeatherHourly>[];
      for (var i = 0; i < times.length && out.length < 24; i++) {
        final t = DateTime.parse(times[i]);
        if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
        out.add(WeatherHourly(
          time: t,
          tempC: temps[i],
          relativeHumidity: humidity[i],
          code: codes[i],
        ));
      }
      _hourlyCache[key] = _CacheEntry(out);
      return out;
    } catch (_) {
      return cached?.data ?? const [];
    }
  }

  /// Luftqualität (PM2.5, PM10, Europäischer AQI). Cached 30 Minuten.
  static Future<AirQuality?> airQuality({
    required double latitude,
    required double longitude,
  }) async {
    final key = _key(latitude, longitude);
    final cached = _aqCache[key];
    if (cached != null && !cached.isExpired) return cached.data;

    final uri = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'hourly': 'pm10,pm2_5,european_aqi',
      'forecast_days': '1',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return cached?.data;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final h = json['hourly'] as Map<String, dynamic>?;
      if (h == null) return cached?.data;
      final pm25list = (h['pm2_5'] as List)
          .map((e) => e == null ? 0.0 : (e as num).toDouble())
          .toList();
      final pm10list = (h['pm10'] as List)
          .map((e) => e == null ? 0.0 : (e as num).toDouble())
          .toList();
      final aqiList = (h['european_aqi'] as List)
          .map((e) => e == null ? 0 : (e as num).toInt())
          .toList();
      // Aktuelle Stunde suchen (letzter nicht-null Wert)
      int idx = pm25list.length - 1;
      final now = DateTime.now().hour;
      if (now < pm25list.length) idx = now;
      final aq = AirQuality(
        pm25: pm25list[idx],
        pm10: pm10list[idx],
        europeanAqi: aqiList[idx],
      );
      _aqCache[key] = _CacheEntry(aq);
      return aq;
    } catch (_) {
      return cached?.data;
    }
  }

  /// Löscht alle Caches (z. B. bei manuellem Reload).
  static void clearCache() {
    _forecastCache.clear();
    _hourlyCache.clear();
    _aqCache.clear();
  }
}

// ── Cache-Hilfklasse ─────────────────────────────────────────────────────────

class _CacheEntry<T> {
  _CacheEntry(this.data) : fetchedAt = DateTime.now();
  final T data;
  final DateTime fetchedAt;
  bool get isExpired =>
      DateTime.now().difference(fetchedAt).inMinutes >= 30;
}

// ── Modelle ───────────────────────────────────────────────────────────────────

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

  String get labelKey {
    if (code == 0) return 'weather.condClear';
    if (code <= 2) return 'weather.condSunny';
    if (code == 3) return 'weather.condCloudy';
    if (code == 45 || code == 48) return 'weather.condFog';
    if (code >= 51 && code <= 57) return 'weather.condDrizzle';
    if (code >= 61 && code <= 67) return 'weather.condRain';
    if (code >= 71 && code <= 77) return 'weather.condSnow';
    if (code >= 80 && code <= 82) return 'weather.condShowers';
    if (code >= 95) return 'weather.condThunderstorm';
    return 'weather.condUnknown';
  }

  // Legacy-Feld (used by existing WeatherWidget)
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

class WeatherHourly {
  const WeatherHourly({
    required this.time,
    required this.tempC,
    required this.relativeHumidity,
    required this.code,
  });

  final DateTime time;
  final double tempC;
  final int relativeHumidity;
  final int code;
}

class AirQuality {
  const AirQuality({
    required this.pm25,
    required this.pm10,
    required this.europeanAqi,
  });

  final double pm25;
  final double pm10;
  final int europeanAqi;

  /// Schlüssel für weather.airQuality* Übersetzungen.
  String get aqiLabelKey {
    if (europeanAqi <= 20) return 'weather.aqGood';
    if (europeanAqi <= 40) return 'weather.aqFair';
    if (europeanAqi <= 60) return 'weather.aqModerate';
    if (europeanAqi <= 80) return 'weather.aqPoor';
    return 'weather.aqVeryPoor';
  }

  Color get aqiColor {
    if (europeanAqi <= 20) return const Color(0xFF4CAF50);
    if (europeanAqi <= 40) return const Color(0xFF8BC34A);
    if (europeanAqi <= 60) return const Color(0xFFFFC107);
    if (europeanAqi <= 80) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}
