/// SKILL: mensaena-features
/// ÖPNV-Routing via Transitous (öffentliche MOTIS-Instanz) — gratis, KEIN Key.
/// Plant Verbindungen zwischen zwei Koordinaten. Defensiv geparst: bei
/// abweichendem Schema/Fehler -> leere Liste (kein Crash).
///
/// API: https://api.transitous.org/api/v1/plan?fromPlace=lat,lng&toPlace=lat,lng
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class TransitLeg {
  const TransitLeg({
    required this.mode,
    required this.line,
    required this.fromName,
    required this.toName,
    required this.start,
    required this.end,
  });
  final String mode; // WALK, BUS, TRAM, SUBWAY, RAIL, ...
  final String line; // routeShortName / headsign, ggf. leer
  final String fromName;
  final String toName;
  final DateTime? start;
  final DateTime? end;
}

class TransitItinerary {
  const TransitItinerary({
    required this.start,
    required this.end,
    required this.durationMin,
    required this.transfers,
    required this.legs,
  });
  final DateTime? start;
  final DateTime? end;
  final int durationMin;
  final int transfers;
  final List<TransitLeg> legs;
}

class TransitService {
  const TransitService._();

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt()).toLocal();
    }
    if (v is String) return DateTime.tryParse(v)?.toLocal();
    return null;
  }

  static Future<List<TransitItinerary>> plan({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final uri = Uri.parse(
      'https://api.transitous.org/api/v1/plan'
      '?fromPlace=$fromLat,$fromLng&toPlace=$toLat,$toLng',
    );
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return const [];
      final j = json.decode(r.body) as Map<String, dynamic>;
      final its = (j['itineraries'] as List?) ?? const [];
      final out = <TransitItinerary>[];
      for (final raw in its) {
        if (raw is! Map) continue;
        final legsRaw = (raw['legs'] as List?) ?? const [];
        final legs = <TransitLeg>[];
        for (final l in legsRaw) {
          if (l is! Map) continue;
          final from = l['from'];
          final to = l['to'];
          legs.add(TransitLeg(
            mode: (l['mode'] as String?) ?? 'WALK',
            line: (l['routeShortName'] as String?) ??
                (l['headsign'] as String?) ??
                '',
            fromName: (from is Map ? from['name'] as String? : null) ?? '',
            toName: (to is Map ? to['name'] as String? : null) ?? '',
            start: _parseTime(l['startTime']),
            end: _parseTime(l['endTime']),
          ));
        }
        final durSec = (raw['duration'] as num?)?.toInt() ?? 0;
        out.add(TransitItinerary(
          start: _parseTime(raw['startTime']),
          end: _parseTime(raw['endTime']),
          durationMin: (durSec / 60).round(),
          transfers: (raw['transfers'] as num?)?.toInt() ?? 0,
          legs: legs,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
