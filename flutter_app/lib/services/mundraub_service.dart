/// SKILL: mensaena-features
/// Wildfrucht-/Sammel-/Verschenk-Punkte via OSM Overpass.
///
/// Original-mundraub.org API ist seit 2025 zu, daher nutzen wir die
/// offene OSM-Datenbank via Overpass. Die OSM-Tags die wir abfragen:
///   - produce=apple|cherry|pear|plum|...    → Wildfruechte/Obstbaeume
///   - amenity=give_box                       → Verschenk-Schraenke
///   - amenity=public_bookcase               → Buecherschraenke
/// Cache: 15min Memory pro Geo-Bucket.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

enum FreePickKind { fruit, giveBox, bookcase }

class FreePickSpot {
  const FreePickSpot({
    required this.id,
    required this.lat,
    required this.lng,
    required this.kind,
    this.name,
    this.tags,
  });

  final String id;
  final double lat;
  final double lng;
  final FreePickKind kind;
  final String? name;
  final Map<String, String>? tags;

  String get displayLabel {
    if (name != null && name!.isNotEmpty) return name!;
    switch (kind) {
      case FreePickKind.fruit:
        final produce = tags?['produce'];
        return produce ?? 'Obstbaum';
      case FreePickKind.giveBox:
        return 'Verschenk-Schrank';
      case FreePickKind.bookcase:
        return 'Bücherschrank';
    }
  }
}

class MundraubService {
  const MundraubService._();

  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 15);

  /// Holt Sammel-Spots in Radius. Nutzt Overpass-API.
  static Future<List<FreePickSpot>> nearby({
    required double lat,
    required double lng,
    int radiusKm = 10,
    int limit = 60,
  }) async {
    final cacheKey =
        '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}:$radiusKm';
    final hit = _cache[cacheKey];
    if (hit != null && DateTime.now().difference(hit.fetchedAt) < _ttl) {
      return hit.data;
    }
    final radiusM = radiusKm * 1000;
    // BUGFIX: Statt nur 'node' nutzen wir 'nwr' (node+way+relation) — viele
    // give_box und Obstbäume sind als WAY oder RELATION getagged (Polygone
    // mit z. B. amenity=give_box auf einem Container-Schrank). 'out center'
    // liefert dann fuer ways/relations einen Center-Punkt statt body.
    // Auch ergaenzt: landuse=orchard (Obstplantagen) zaehlen als fruit-Quelle.
    final q = '[out:json][timeout:25];'
        '('
        'nwr["produce"](around:$radiusM,$lat,$lng);'
        'nwr["landuse"="orchard"](around:$radiusM,$lat,$lng);'
        'nwr["amenity"="give_box"](around:$radiusM,$lat,$lng);'
        'nwr["amenity"="public_bookcase"](around:$radiusM,$lat,$lng);'
        ');out center $limit;';
    // WICHTIG: Overpass antwortet OHNE User-Agent-Header mit HTTP 406 → 0
    // Spots. Header setzen + Mirror als Fallback (Hauptserver oft überlastet).
    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
    ];
    try {
      http.Response? r;
      for (final ep in endpoints) {
        try {
          final resp = await http.post(
            Uri.parse(ep),
            headers: const {'User-Agent': 'mensaena/1.0 (de.mensaena.app)'},
            body: {'data': q},
          ).timeout(const Duration(seconds: 30));
          if (resp.statusCode == 200) {
            r = resp;
            break;
          }
          debugPrint('[Mundraub] $ep HTTP ${resp.statusCode}');
        } catch (e) {
          debugPrint('[Mundraub] $ep failed: $e');
        }
      }
      if (r == null) return const [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      final elements = (j['elements'] as List?) ?? const [];
      final out = <FreePickSpot>[];
      for (final el in elements.whereType<Map<String, dynamic>>()) {
        final id = '${el['type']}/${el['id']}';
        // node hat lat/lon direkt, way/relation hat sie unter 'center'.
        double? plat = (el['lat'] as num?)?.toDouble();
        double? plng = (el['lon'] as num?)?.toDouble();
        if (plat == null || plng == null) {
          final center = el['center'] as Map<String, dynamic>?;
          plat = (center?['lat'] as num?)?.toDouble();
          plng = (center?['lon'] as num?)?.toDouble();
        }
        final tags = (el['tags'] as Map?)?.cast<String, dynamic>();
        if (plat == null || plng == null || tags == null) continue;
        FreePickKind kind;
        if (tags['amenity'] == 'give_box') {
          kind = FreePickKind.giveBox;
        } else if (tags['amenity'] == 'public_bookcase') {
          kind = FreePickKind.bookcase;
        } else if (tags['produce'] != null ||
            tags['landuse'] == 'orchard') {
          kind = FreePickKind.fruit;
        } else {
          continue;
        }
        final cleanTags =
            tags.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        out.add(FreePickSpot(
          id: id,
          lat: plat,
          lng: plng,
          kind: kind,
          name: tags['name'] as String?,
          tags: cleanTags,
        ));
      }
      // Cache trimmen
      if (_cache.length > 12) {
        final oldest = _cache.entries.toList()
          ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));
        _cache.remove(oldest.first.key);
      }
      _cache[cacheKey] = _CacheEntry(out, DateTime.now());
      return out;
    } catch (e) {
      debugPrint('[Mundraub] Overpass failed: $e');
      return const [];
    }
  }
}

class _CacheEntry {
  _CacheEntry(this.data, this.fetchedAt);
  final List<FreePickSpot> data;
  final DateTime fetchedAt;
}
