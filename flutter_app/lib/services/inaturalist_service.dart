/// SKILL: mensaena-features
/// iNaturalist API — Bestimmung + Observations.
/// https://api.inaturalist.org (kein API-Key)
///
/// Nutzung:
///  - Foto eines Tiers/einer Pflanze hochladen → Identifikation
///  - Recent Observations rund um GPS-Punkt holen
///  - Per taxon_id auf spezielle Gruppen filtern (3=Aves Voegel,
///    47126=Plantae Pflanzen, 40151=Mammalia Saeugetiere)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class INaturalistObservation {
  const INaturalistObservation({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.observedAt,
    required this.lat,
    required this.lng,
    this.placeGuess,
    this.photoUrl,
  });

  final int id;
  final String commonName;
  final String scientificName;
  final DateTime? observedAt;
  final double? lat;
  final double? lng;
  final String? placeGuess;
  final String? photoUrl;

  String get inatUrl => 'https://www.inaturalist.org/observations/$id';
}

class INaturalistService {
  const INaturalistService._();

  static const String _base = 'https://api.inaturalist.org/v1';

  /// Recent observations in einem Radius. taxonId = 3 fuer Voegel,
  /// 47126 fuer Pflanzen, null = alles.
  static Future<List<INaturalistObservation>> recent({
    required double lat,
    required double lng,
    int radiusKm = 25,
    int? taxonId,
    int perPage = 12,
  }) async {
    final params = <String, String>{
      'lat': '$lat',
      'lng': '$lng',
      'radius': '$radiusKm',
      'per_page': '$perPage',
      'order_by': 'observed_on',
      'quality_grade': 'research,needs_id',
    };
    if (taxonId != null) params['taxon_id'] = '$taxonId';
    final uri = Uri.parse('$_base/observations')
        .replace(queryParameters: params);
    try {
      final r = await http
          .get(uri, headers: {'User-Agent': 'Mensaena/4.0 (de.mensaena.app)'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      final results = j['results'] as List? ?? const [];
      final out = <INaturalistObservation>[];
      for (final raw in results.whereType<Map<String, dynamic>>()) {
        final taxon = raw['taxon'] as Map<String, dynamic>?;
        final geojson = raw['geojson'] as Map<String, dynamic>?;
        final coords = geojson?['coordinates'] as List?;
        out.add(INaturalistObservation(
          id: (raw['id'] as num).toInt(),
          commonName: (taxon?['preferred_common_name'] as String?) ??
              (taxon?['name'] as String?) ?? '—',
          scientificName: (taxon?['name'] as String?) ?? '',
          observedAt: DateTime.tryParse(
              raw['observed_on_string'] as String? ??
                  raw['observed_on'] as String? ??
                  ''),
          lat: coords != null && coords.length > 1
              ? (coords[1] as num).toDouble()
              : null,
          lng: coords != null && coords.isNotEmpty
              ? (coords[0] as num).toDouble()
              : null,
          placeGuess: raw['place_guess'] as String?,
          photoUrl: (raw['photos'] as List?)
                  ?.cast<Map<String, dynamic>>()
                  .firstOrNull?['url'] as String?,
        ));
      }
      return out;
    } catch (e) {
      debugPrint('[iNaturalist] recent failed: $e');
      return const [];
    }
  }

  /// Bestimmung einer Spezies aus einem hochgeladenen Foto.
  /// Returns Top-Treffer-Liste (max 5). Kein Key noetig.
  static Future<List<INaturalistIdentificationGuess>> identifyFromPhoto(
      File photo) async {
    try {
      final uri = Uri.parse('$_base/computervision/score_image');
      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('image', photo.path))
        ..headers['User-Agent'] = 'Mensaena/4.0 (de.mensaena.app)';
      final streamed = await req.send().timeout(const Duration(seconds: 25));
      if (streamed.statusCode != 200) return const [];
      final body = await streamed.stream.bytesToString();
      final j = json.decode(body) as Map<String, dynamic>;
      final results = j['results'] as List? ?? const [];
      final out = <INaturalistIdentificationGuess>[];
      for (final raw in results.whereType<Map<String, dynamic>>()) {
        final taxon = raw['taxon'] as Map<String, dynamic>?;
        out.add(INaturalistIdentificationGuess(
          taxonId: (taxon?['id'] as num?)?.toInt() ?? 0,
          commonName:
              (taxon?['preferred_common_name'] as String?) ?? '—',
          scientificName: (taxon?['name'] as String?) ?? '',
          score: (raw['combined_score'] as num?)?.toDouble() ??
              (raw['vision_score'] as num?)?.toDouble() ?? 0.0,
        ));
        if (out.length >= 5) break;
      }
      return out;
    } catch (e) {
      debugPrint('[iNaturalist] identify failed: $e');
      return const [];
    }
  }
}

class INaturalistIdentificationGuess {
  const INaturalistIdentificationGuess({
    required this.taxonId,
    required this.commonName,
    required this.scientificName,
    required this.score,
  });
  final int taxonId;
  final String commonName;
  final String scientificName;
  final double score;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
