/// SKILL: mensaena-features
/// Air Quality Index via OpenAQ — global, gratis, ohne API-Key.
/// Liefert PM2.5/PM10/O3/NO2/SO2/CO-Werte rund um GPS-Punkt.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AirQualitySample {
  const AirQualitySample({
    required this.location,
    required this.city,
    required this.country,
    required this.parameter,
    required this.value,
    required this.unit,
    required this.measuredAt,
    required this.lat,
    required this.lng,
  });

  final String location;
  final String? city;
  final String country;
  final String parameter; // 'pm25','pm10','o3','no2','so2','co'
  final double value;
  final String unit;
  final DateTime measuredAt;
  final double lat;
  final double lng;

  /// WHO-Grenzwert-Vergleich → 0..5 Score (0=gut, 5=kritisch).
  /// Annual mean guidelines (WHO 2021).
  int get whoLevel {
    switch (parameter) {
      case 'pm25':
        if (value <= 5) return 0;
        if (value <= 10) return 1;
        if (value <= 15) return 2;
        if (value <= 25) return 3;
        if (value <= 50) return 4;
        return 5;
      case 'pm10':
        if (value <= 15) return 0;
        if (value <= 30) return 1;
        if (value <= 45) return 2;
        if (value <= 75) return 3;
        if (value <= 150) return 4;
        return 5;
      case 'o3':
        if (value <= 60) return 0;
        if (value <= 100) return 1;
        if (value <= 140) return 2;
        if (value <= 180) return 3;
        if (value <= 240) return 4;
        return 5;
      case 'no2':
        if (value <= 10) return 0;
        if (value <= 25) return 1;
        if (value <= 40) return 2;
        if (value <= 100) return 3;
        if (value <= 200) return 4;
        return 5;
      default:
        return 0;
    }
  }
}

class AirQualityService {
  const AirQualityService._();

  /// OpenAQ v3 — public, no key needed.
  /// Liefert die letzten Messungen für die nächstgelegenen Stationen.
  static Future<List<AirQualitySample>> nearby({
    required double lat,
    required double lng,
    int radiusKm = 25,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      'https://api.openaq.org/v3/locations'
      '?coordinates=$lat,$lng'
      '&radius=${radiusKm * 1000}'
      '&limit=$limit'
      '&order_by=distance'
      '&sort_order=asc',
    );
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      final results = j['results'] as List? ?? const [];
      final out = <AirQualitySample>[];
      for (final loc in results.whereType<Map<String, dynamic>>()) {
        final sensors = loc['sensors'] as List? ?? const [];
        final coords = loc['coordinates'] as Map<String, dynamic>? ?? const {};
        final lat = (coords['latitude'] as num?)?.toDouble();
        final lng = (coords['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        for (final s in sensors.whereType<Map<String, dynamic>>()) {
          final param = s['parameter'] as Map<String, dynamic>? ?? const {};
          final name = param['name'] as String? ?? '';
          if (!const ['pm25', 'pm10', 'o3', 'no2', 'so2', 'co'].contains(name)) {
            continue;
          }
          final latest = s['latest'] as Map<String, dynamic>?;
          if (latest == null) continue;
          final value = (latest['value'] as num?)?.toDouble();
          final ts = latest['datetime'] as Map<String, dynamic>?;
          final utc = ts?['utc'] as String?;
          if (value == null || utc == null) continue;
          out.add(AirQualitySample(
            location: (loc['name'] as String?) ?? 'Station',
            city: loc['city'] as String?,
            country:
                (loc['country'] as Map<String, dynamic>?)?['code'] as String? ??
                    '',
            parameter: name,
            value: value,
            unit: (param['units'] as String?) ?? 'µg/m³',
            measuredAt: DateTime.tryParse(utc) ?? DateTime.now(),
            lat: lat,
            lng: lng,
          ));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
