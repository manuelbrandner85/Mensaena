/// SKILL: mensaena-features
/// WaterLevelService (V9) — Pegelonline.wsv.de public API client.
///
/// Surfaces nearby water-level stations (rivers, lakes) so the crisis /
/// weather module can warn about flooding. The PEGELONLINE REST API is
/// provided free of charge by the German Federal Waterways and Shipping
/// Administration (WSV) — no API key required.
///
/// Docs: https://www.pegelonline.wsv.de/webservices/rest-api/v2
///
/// A short in-memory cache (15 min) keeps us friendly to the upstream and
/// makes the UI snappy on repeated panel opens.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// Trend of the most recent measurement compared to the previous one.
/// Pegelonline returns -1 / 0 / 1; we normalize to readable strings.
enum WaterTrend { rising, falling, stable, unknown }

class WaterLevel {
  const WaterLevel({
    required this.stationName,
    required this.level,
    required this.trend,
    required this.timestamp,
    this.warning = false,
    this.unit = 'cm',
    this.water,
    this.latitude,
    this.longitude,
  });

  /// Human-readable station name (e.g. "KOELN").
  final String stationName;

  /// Current measurement value (typically water level in cm).
  final double level;

  /// Trend of the most recent measurement: rising / falling / stable.
  final WaterTrend trend;

  /// Timestamp of the most recent measurement.
  final DateTime timestamp;

  /// True if the station currently reports an elevated / warning level.
  /// Pegelonline does not return a unified flag, so this is a heuristic
  /// applied when the level exceeds the station's "high-water" threshold.
  final bool warning;

  /// Unit of [level] — usually "cm".
  final String unit;

  /// River / body of water the station sits on (e.g. "RHEIN").
  final String? water;

  final double? latitude;
  final double? longitude;
}

class WaterLevelService {
  const WaterLevelService._();

  static const String _base =
      'https://www.pegelonline.wsv.de/webservices/rest-api/v2';

  // Tiny in-memory cache: keyed by rounded lat/lng/radius bucket.
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 15);

  /// Fetches up to ~15 nearby stations, sorted by the API, with their most
  /// recent measurement. Returns an empty list if the request fails — the
  /// UI should treat it as "no data available".
  static Future<List<WaterLevel>> nearby({
    required double lat,
    required double lng,
    int radiusKm = 50,
  }) async {
    final cacheKey =
        '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}_$radiusKm';
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.fetchedAt) < _ttl) {
      return cached.data;
    }

    final uri = Uri.parse(
      '$_base/stations.json'
      '?prettyprint=false'
      '&latitude=$lat'
      '&longitude=$lng'
      '&radius=$radiusKm'
      '&includeTimeseries=true'
      '&includeCurrentMeasurement=true',
    );

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        debugPrint('WaterLevelService: HTTP ${resp.statusCode}');
        return const [];
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) return const [];

      final result = <WaterLevel>[];
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final station = Map<String, dynamic>.from(raw);
        final level = _extractCurrentMeasurement(station);
        if (level == null) continue;
        result.add(level);
      }
      _cache[cacheKey] =
          _CacheEntry(data: result, fetchedAt: DateTime.now());
      return result;
    } catch (e) {
      debugPrint('WaterLevelService: fetch failed: $e');
      return const [];
    }
  }

  /// Pulls the most recent measurement out of a station JSON object and maps
  /// the trend code into our enum. Returns null when the station lacks a
  /// usable current measurement.
  static WaterLevel? _extractCurrentMeasurement(Map<String, dynamic> station) {
    final timeseries = station['timeseries'];
    if (timeseries is! List) return null;

    Map<String, dynamic>? waterSeries;
    for (final ts in timeseries) {
      if (ts is Map &&
          (ts['shortname']?.toString().toUpperCase() == 'W' ||
              ts['shortname']?.toString().toUpperCase() == 'WATERLEVEL')) {
        waterSeries = Map<String, dynamic>.from(ts);
        break;
      }
    }
    // Fall back to the first series when no explicit water-level series.
    waterSeries ??= timeseries.isNotEmpty && timeseries.first is Map
        ? Map<String, dynamic>.from(timeseries.first as Map)
        : null;
    if (waterSeries == null) return null;

    final measurement = waterSeries['currentMeasurement'];
    if (measurement is! Map) return null;
    final value = (measurement['value'] as num?)?.toDouble();
    if (value == null) return null;

    final ts = DateTime.tryParse(measurement['timestamp']?.toString() ?? '') ??
        DateTime.now();
    final trend = _mapTrend(measurement['trend']);
    final warning = _isWarning(waterSeries, value);

    return WaterLevel(
      stationName: (station['longname'] ?? station['shortname'] ?? '—')
          .toString(),
      level: value,
      trend: trend,
      timestamp: ts,
      warning: warning,
      unit: (waterSeries['unit'] as String?) ?? 'cm',
      water: (station['water'] is Map)
          ? (station['water'] as Map)['longname']?.toString()
          : null,
      latitude: (station['latitude'] as num?)?.toDouble(),
      longitude: (station['longitude'] as num?)?.toDouble(),
    );
  }

  /// Pegelonline trend convention: -1 = falling, 0 = stable, 1 = rising.
  static WaterTrend _mapTrend(Object? raw) {
    if (raw is num) {
      if (raw > 0) return WaterTrend.rising;
      if (raw < 0) return WaterTrend.falling;
      return WaterTrend.stable;
    }
    final s = raw?.toString().toLowerCase() ?? '';
    if (s == 'rising' || s == '1') return WaterTrend.rising;
    if (s == 'falling' || s == '-1') return WaterTrend.falling;
    if (s == 'stable' || s == '0') return WaterTrend.stable;
    return WaterTrend.unknown;
  }

  /// Heuristic: a station counts as "warning" when the value exceeds the
  /// configured high-water (Hochwasser) threshold returned in `gaugeZero`
  /// or `characteristicValues`. Conservative: returns false if no threshold
  /// is published.
  static bool _isWarning(Map<String, dynamic> series, double value) {
    final chars = series['characteristicValues'];
    if (chars is! List) return false;
    for (final c in chars) {
      if (c is! Map) continue;
      final name = c['shortname']?.toString().toUpperCase() ?? '';
      if (name.contains('HHW') || name.contains('MHW') || name.contains('HSW')) {
        final threshold = (c['value'] as num?)?.toDouble();
        if (threshold != null && value >= threshold) return true;
      }
    }
    return false;
  }

  /// Clears the in-memory cache. Mostly useful in tests.
  static void clearCache() => _cache.clear();
}

class _CacheEntry {
  _CacheEntry({required this.data, required this.fetchedAt});
  final List<WaterLevel> data;
  final DateTime fetchedAt;
}
