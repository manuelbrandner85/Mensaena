/// SKILL: mensaena-features
/// E-Auto-Ladestationen via OSM Overpass.
///
/// OpenChargeMap braucht seit 2025 einen API-Key (gratis aber Registrierung).
/// Stattdessen: OSM-Tag amenity=charging_station via Overpass. Liefert
/// >90% der OpenChargeMap-Datenbasis (die meisten Betreiber speisen ihre
/// Stationen direkt in OSM ein).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class ChargeStation {
  const ChargeStation({
    required this.id,
    required this.lat,
    required this.lng,
    this.name,
    this.operator,
    this.socket,
    this.capacityKw,
    this.fee,
  });

  final String id;
  final double lat;
  final double lng;
  final String? name;
  final String? operator;
  final String? socket; // z.B. 'type2', 'ccs'
  final double? capacityKw;
  final bool? fee; // true=kostenpflichtig
}

class ChargeStationsService {
  const ChargeStationsService._();

  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 15);

  static Future<List<ChargeStation>> nearby({
    required double lat,
    required double lng,
    int radiusKm = 15,
    int limit = 80,
  }) async {
    final key =
        '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}:$radiusKm';
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.fetchedAt) < _ttl) {
      return hit.data;
    }
    final radiusM = radiusKm * 1000;
    final q = '[out:json][timeout:15];'
        'node["amenity"="charging_station"](around:$radiusM,$lat,$lng);'
        'out body $limit;';
    try {
      final r = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': q},
          )
          .timeout(const Duration(seconds: 18));
      if (r.statusCode != 200) {
        debugPrint('[ChargeStations] HTTP ${r.statusCode}');
        return const [];
      }
      final j = json.decode(r.body) as Map<String, dynamic>;
      final elements = (j['elements'] as List?) ?? const [];
      final out = <ChargeStation>[];
      for (final el in elements.whereType<Map<String, dynamic>>()) {
        final plat = (el['lat'] as num?)?.toDouble();
        final plng = (el['lon'] as num?)?.toDouble();
        final tags = (el['tags'] as Map?)?.cast<String, dynamic>();
        if (plat == null || plng == null) continue;
        final feeStr = tags?['fee'] as String?;
        final socketStr = (tags?['socket:type2'] != null)
            ? 'type2'
            : (tags?['socket:ccs'] != null)
                ? 'ccs'
                : (tags?['socket'] as String?);
        double? capacityKw;
        final raw = tags?['capacity'] ?? tags?['maxstay:kw'];
        if (raw is String) capacityKw = double.tryParse(raw);
        out.add(ChargeStation(
          id: '${el['type']}/${el['id']}',
          lat: plat,
          lng: plng,
          name: tags?['name'] as String?,
          operator: tags?['operator'] as String?,
          socket: socketStr,
          capacityKw: capacityKw,
          fee: feeStr == null ? null : (feeStr.toLowerCase() == 'yes'),
        ));
      }
      if (_cache.length > 12) {
        final oldest = _cache.entries.toList()
          ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));
        _cache.remove(oldest.first.key);
      }
      _cache[key] = _CacheEntry(out, DateTime.now());
      return out;
    } catch (e) {
      debugPrint('[ChargeStations] failed: $e');
      return const [];
    }
  }
}

class _CacheEntry {
  _CacheEntry(this.data, this.fetchedAt);
  final List<ChargeStation> data;
  final DateTime fetchedAt;
}
