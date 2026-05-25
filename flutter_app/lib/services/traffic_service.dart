/// SKILL: mensaena-features
/// TrafficService — Verkehrsmeldungen via Autobahn-App-API.
///
/// Datenquelle: https://verkehr.autobahn.de/o/autobahn/A{road}/services/warning
/// — kostenlose offene API der Bundesregierung. Nur DE-Autobahnen.
///
/// Wir laden eine kleine Auswahl der grossen Autobahnen (A1..A9 +
/// einige regionale), gruppieren die Meldungen und sortieren nach
/// "isBlocked" zuerst, dann alphabetisch. Cache 15min.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class TrafficWarning {
  const TrafficWarning({
    required this.road,
    required this.title,
    required this.subtitle,
    required this.isBlocked,
  });

  final String road;
  final String title;
  final String subtitle;
  final bool isBlocked;
}

class TrafficService {
  const TrafficService._();

  /// Die meistbefahrenen Autobahnen — fuer User in ganz DE relevant.
  /// Mehr Roads = mehr HTTP-Calls = langsamer; 9 ist ein guter
  /// Kompromiss zwischen Coverage und Performance.
  static const List<String> _coreRoads = [
    'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9',
  ];

  static DateTime? _cachedAt;
  static List<TrafficWarning>? _cached;
  static const _ttl = Duration(minutes: 15);

  /// Liefert die Top-N Verkehrswarnungen, gefiltert auf Vollsperrungen
  /// + groessere Behinderungen. Bei Netzwerkfehler: leere Liste.
  static Future<List<TrafficWarning>> top({int limit = 5}) async {
    if (_cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _ttl) {
      return _cached!.take(limit).toList();
    }
    final out = <TrafficWarning>[];
    try {
      final futures = _coreRoads.map(_fetchRoad);
      final all = await Future.wait(futures, eagerError: false);
      for (final list in all) {
        out.addAll(list);
      }
      out.sort((a, b) {
        if (a.isBlocked != b.isBlocked) return a.isBlocked ? -1 : 1;
        return a.road.compareTo(b.road);
      });
      _cached = out;
      _cachedAt = DateTime.now();
      return out.take(limit).toList();
    } catch (e) {
      debugPrint('[TrafficService] failed: $e');
      return const <TrafficWarning>[];
    }
  }

  static Future<List<TrafficWarning>> _fetchRoad(String road) async {
    try {
      final uri = Uri.parse(
          'https://verkehr.autobahn.de/o/autobahn/$road/services/warning');
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return const <TrafficWarning>[];
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (j['warning'] as List?) ?? const [];
      final out = <TrafficWarning>[];
      for (final w in list) {
        if (w is! Map) continue;
        final title = (w['title'] as String?) ?? '';
        final subtitle = (w['subtitle'] as String?) ?? '';
        final desc = (w['description'] as List?)?.join(' ') ?? '';
        final isBlocked = (w['isBlocked'] as String?) == 'true' ||
            title.toLowerCase().contains('sperr');
        out.add(TrafficWarning(
          road: road,
          title: title.isEmpty ? 'Meldung' : title,
          subtitle: subtitle.isEmpty ? desc : subtitle,
          isBlocked: isBlocked,
        ));
      }
      return out;
    } catch (_) {
      return const <TrafficWarning>[];
    }
  }
}
