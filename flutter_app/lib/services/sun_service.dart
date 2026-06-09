/// SKILL: mensaena-features
/// Sonnenauf/-untergang via Open-Meteo Forecast API.
/// https://api.open-meteo.com (gratis, kein Key).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class SunData {
  const SunData({
    required this.sunrise,
    required this.sunset,
    required this.solarNoon,
  });

  final DateTime sunrise;
  final DateTime sunset;
  final DateTime solarNoon;

  /// "Golden Hour" am Morgen: 30 Min nach Sonnenaufgang.
  DateTime get goldenMorningEnd => sunrise.add(const Duration(minutes: 60));

  /// "Golden Hour" am Abend: 60 Min vor Sonnenuntergang.
  DateTime get goldenEveningStart =>
      sunset.subtract(const Duration(minutes: 60));

  Duration get dayLength => sunset.difference(sunrise);

  /// True wenn jetzt Golden Hour ist.
  bool get isGoldenHourNow {
    final now = DateTime.now();
    return (now.isAfter(sunrise) && now.isBefore(goldenMorningEnd)) ||
        (now.isAfter(goldenEveningStart) && now.isBefore(sunset));
  }

  bool get isNight {
    final now = DateTime.now();
    return now.isBefore(sunrise) || now.isAfter(sunset);
  }
}

class SunService {
  const SunService._();

  static final Map<String, ({DateTime at, SunData data})> _cache = {};

  static Future<SunData?> fetchForPosition({
    required double lat,
    required double lng,
  }) async {
    final key =
        '${lat.toStringAsFixed(1)},${lng.toStringAsFixed(1)}:${DateTime.now().day}';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at).inHours < 6) {
      return hit.data;
    }
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&daily=sunrise,sunset'
        '&timezone=auto'
        '&forecast_days=1',
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = json.decode(r.body) as Map<String, dynamic>;
      final daily = j['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;
      final sunriseList = (daily['sunrise'] as List?)?.cast<String>();
      final sunsetList = (daily['sunset'] as List?)?.cast<String>();
      if (sunriseList == null ||
          sunsetList == null ||
          sunriseList.isEmpty ||
          sunsetList.isEmpty) {
        return null;
      }
      final sunrise = DateTime.parse(sunriseList.first).toUtc();
      final sunset = DateTime.parse(sunsetList.first).toUtc();
      final solarNoon = sunrise.add(sunset.difference(sunrise) ~/ 2);
      final data = SunData(
        sunrise: sunrise,
        sunset: sunset,
        solarNoon: solarNoon,
      );
      _cache[key] = (at: DateTime.now(), data: data);
      return data;
    } catch (e) {
      debugPrint('[SunService] failed: $e');
      return null;
    }
  }
}
