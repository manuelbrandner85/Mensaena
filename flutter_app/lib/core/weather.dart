import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1 Tag der 7-Tages-Vorhersage von Open-Meteo (kostenlos, kein API-Key).
class WeatherForecastDay {
  const WeatherForecastDay({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.weatherCode,
    required this.precipitationProbability,
  });

  final DateTime date;
  final double tempMin;
  final double tempMax;
  final int weatherCode;
  final int precipitationProbability;

  /// WMO-Wetter-Code → Emoji.
  /// https://open-meteo.com/en/docs#weathervariables
  String get emoji {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 2) return '⛅';
    if (weatherCode == 3) return '☁️';
    if (weatherCode <= 49) return '🌫️';
    if (weatherCode <= 67) return '🌧️';
    if (weatherCode <= 77) return '🌨️';
    if (weatherCode <= 82) return '🌧️';
    if (weatherCode <= 86) return '🌨️';
    if (weatherCode <= 99) return '⛈️';
    return '🌡️';
  }

  String get summary {
    if (weatherCode == 0) return 'Sonnig';
    if (weatherCode <= 2) return 'Heiter';
    if (weatherCode == 3) return 'Bewölkt';
    if (weatherCode <= 49) return 'Nebel';
    if (weatherCode <= 67) return 'Regen';
    if (weatherCode <= 77) return 'Schnee';
    if (weatherCode <= 82) return 'Schauer';
    if (weatherCode <= 86) return 'Schneeschauer';
    if (weatherCode <= 99) return 'Gewitter';
    return 'Wetter';
  }
}

/// Kostenlose 7-Tages-Wettervorhersage von Open-Meteo.
/// Cacht 1h pro lat/lng-Kombination.
class WeatherService {
  WeatherService._();

  static const _ttl = Duration(hours: 1);

  static String _cacheKey(double lat, double lon) {
    final latRound = (lat * 10).round() / 10;
    final lonRound = (lon * 10).round() / 10;
    return 'weather.$latRound.$lonRound';
  }

  static Future<List<WeatherForecastDay>> fetch({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _cacheKey(latitude, longitude);
      final tsKey = '$key.ts';
      final cached = prefs.getString(key);
      final ts = prefs.getInt(tsKey);
      if (cached != null && ts != null) {
        final age = DateTime.now().millisecondsSinceEpoch - ts;
        if (age < _ttl.inMilliseconds) return _decode(cached);
      }

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 8),
      ),);
      final res = await dio.get<dynamic>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'daily':
              'weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
          'timezone': 'Europe/Berlin',
          'forecast_days': 7,
        },
      );
      if (res.statusCode != 200) {
        return cached != null ? _decode(cached) : const [];
      }
      final body =
          res.data is String ? res.data as String : jsonEncode(res.data);
      await prefs.setString(key, body);
      await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      return _decode(body);
    } catch (e, st) {
      debugPrint('WeatherService.fetch failed: $e\n$st');
      return const [];
    }
  }

  static List<WeatherForecastDay> _decode(String body) {
    try {
      final raw = jsonDecode(body);
      if (raw is! Map<String, dynamic>) return const [];
      final daily = raw['daily'] as Map<String, dynamic>?;
      if (daily == null) return const [];
      final dates = (daily['time'] as List?)?.cast<String>() ?? const [];
      final codes = (daily['weathercode'] as List?)?.cast<num>() ?? const [];
      final tmax =
          (daily['temperature_2m_max'] as List?)?.cast<num>() ?? const [];
      final tmin =
          (daily['temperature_2m_min'] as List?)?.cast<num>() ?? const [];
      final pop =
          (daily['precipitation_probability_max'] as List?)?.cast<num?>() ??
              const [];
      final out = <WeatherForecastDay>[];
      for (var i = 0; i < dates.length; i++) {
        final d = DateTime.tryParse(dates[i]);
        if (d == null) continue;
        out.add(WeatherForecastDay(
          date: d,
          tempMin: i < tmin.length ? tmin[i].toDouble() : 0,
          tempMax: i < tmax.length ? tmax[i].toDouble() : 0,
          weatherCode: i < codes.length ? codes[i].toInt() : 0,
          precipitationProbability:
              i < pop.length ? (pop[i]?.toInt() ?? 0) : 0,
        ),);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
