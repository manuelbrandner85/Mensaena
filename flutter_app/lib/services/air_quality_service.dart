/// SKILL: mensaena-features
/// Air Quality via Open-Meteo Air Quality API — global, gratis, KEIN API-Key.
///
/// Migration: Bis 2024 wurde OpenAQ v3 genutzt — der Dienst verlangt
/// seither einen `X-API-Key`-Header (siehe HTTP 401 bei keyless calls).
/// Open-Meteo liefert dieselben Schadstoffe (PM2.5, PM10, O3, NO2, SO2, CO)
/// PLUS einen vorgefertigten European-AQI-Score, hat keine Key-Pflicht und
/// einen sehr großzügigen kostenlosen Tier.
///
/// API: https://open-meteo.com/en/docs/air-quality-api
/// Beispiel:
///   GET https://air-quality-api.open-meteo.com/v1/air-quality
///        ?latitude=52.52&longitude=13.405
///        &current=european_aqi,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,
///                  sulphur_dioxide,ozone
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

  // Open-Meteo nutzt API-Feldnamen die sich von WHO-Codes unterscheiden:
  static const Map<String, String> _apiToCode = {
    'pm2_5': 'pm25',
    'pm10': 'pm10',
    'ozone': 'o3',
    'nitrogen_dioxide': 'no2',
    'sulphur_dioxide': 'so2',
    'carbon_monoxide': 'co',
  };

  /// Liefert die aktuellen Messwerte am gegebenen GPS-Punkt. Open-Meteo
  /// liefert EINE virtuelle Station (auf 0.1° gerastert) — daher gibt diese
  /// Methode normalerweise 6 Samples zurueck (je ein Sample pro Parameter).
  ///
  /// `radiusKm` und `limit` werden aus API-Kompatibilitaet beibehalten,
  /// haben aber bei Open-Meteo keine direkte Entsprechung.
  static Future<List<AirQualitySample>> nearby({
    required double lat,
    required double lng,
    int radiusKm = 25,
    int limit = 20,
  }) async {
    final fields = _apiToCode.keys.join(',');
    final uri = Uri.parse(
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=$lat&longitude=$lng'
      '&current=$fields',
    );
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      final current = j['current'] as Map<String, dynamic>? ?? const {};
      final units = j['current_units'] as Map<String, dynamic>? ?? const {};
      final timeIso = current['time'] as String?;
      final measuredAt =
          DateTime.tryParse(timeIso ?? '') ?? DateTime.now();
      final stationLat = (j['latitude'] as num?)?.toDouble() ?? lat;
      final stationLng = (j['longitude'] as num?)?.toDouble() ?? lng;

      final out = <AirQualitySample>[];
      for (final entry in _apiToCode.entries) {
        final raw = current[entry.key];
        if (raw == null) continue;
        final value = (raw as num).toDouble();
        out.add(AirQualitySample(
          location: 'Open-Meteo Grid',
          city: null,
          country: '',
          parameter: entry.value,
          value: value,
          unit: (units[entry.key] as String?) ?? 'µg/m³',
          measuredAt: measuredAt,
          lat: stationLat,
          lng: stationLng,
        ));
      }
      return out.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }
}
