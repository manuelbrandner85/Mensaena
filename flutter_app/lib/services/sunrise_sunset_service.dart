/// SKILL: mensaena-features
/// Sunrise-Sunset API — exakte Sonnenzeiten pro GPS-Punkt.
/// https://api.sunrise-sunset.org/json (gratis, kein Key)
///
/// Wird vom Cinema-Theme-Provider genutzt: die 6 Tageszeit-Phasen
/// shiften nicht mehr nach festen Uhrzeiten (5/8/12/17/20/23) sondern
/// nach realer Sonne — z.B. Morgendaemmerung-Phase startet zur echten
/// civil_twilight_begin und endet bei sunrise.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class SunTimes {
  const SunTimes({
    required this.sunrise,
    required this.sunset,
    required this.solarNoon,
    required this.civilTwilightBegin,
    required this.civilTwilightEnd,
    required this.dayLengthSeconds,
  });

  final DateTime sunrise;
  final DateTime sunset;
  final DateTime solarNoon;
  final DateTime civilTwilightBegin;
  final DateTime civilTwilightEnd;
  final int dayLengthSeconds;

  /// Hilfs-Getter: true wenn jetzt zwischen sunset und sunrise.
  bool isNight(DateTime now) =>
      now.isAfter(sunset) || now.isBefore(sunrise);
}

class SunriseSunsetService {
  const SunriseSunsetService._();

  static final Map<String, _CacheEntry> _cache = {};

  /// Holt Sonnenzeiten fuer (lat, lng). Cache pro 0.1°-Bucket + Datum.
  /// Bei Netzfehler: null (Caller faellt auf Uhrzeit-Heuristik zurueck).
  static Future<SunTimes?> forLocation({
    required double lat,
    required double lng,
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now().toUtc();
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}'
        '-${d.day.toString().padLeft(2, '0')}';
    final key =
        '${lat.toStringAsFixed(1)},${lng.toStringAsFixed(1)}:$dateStr';
    final hit = _cache[key];
    if (hit != null) return hit.times;

    try {
      final uri = Uri.parse(
          'https://api.sunrise-sunset.org/json'
          '?lat=$lat&lng=$lng&date=$dateStr&formatted=0');
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = json.decode(r.body) as Map<String, dynamic>;
      if (j['status'] != 'OK') return null;
      final results = j['results'] as Map<String, dynamic>;
      final times = SunTimes(
        sunrise: DateTime.parse(results['sunrise'] as String).toLocal(),
        sunset: DateTime.parse(results['sunset'] as String).toLocal(),
        solarNoon: DateTime.parse(results['solar_noon'] as String).toLocal(),
        civilTwilightBegin:
            DateTime.parse(results['civil_twilight_begin'] as String).toLocal(),
        civilTwilightEnd:
            DateTime.parse(results['civil_twilight_end'] as String).toLocal(),
        dayLengthSeconds: (results['day_length'] as num).toInt(),
      );
      // Cache trimmen — max 30 Eintraege (geo-buckets × Datum).
      if (_cache.length > 30) {
        _cache.remove(_cache.keys.first);
      }
      _cache[key] = _CacheEntry(times);
      return times;
    } catch (e) {
      debugPrint('[SunriseSunset] failed: $e');
      return null;
    }
  }
}

class _CacheEntry {
  _CacheEntry(this.times);
  final SunTimes times;
}
