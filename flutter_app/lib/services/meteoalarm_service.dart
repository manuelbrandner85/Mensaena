/// SKILL: mensaena-features
/// MeteoAlarm (EUMETNET) — offizielle Wetterwarnungen für 30+ EU-Länder.
/// Single-Source aller nationalen Meteo-Behörden (DWD, AEMET, Météo-France, ...).
/// Atom/CAP RSS, gratis ohne API-Key. 15min Memory-Cache.
/// https://feeds.meteoalarm.org
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

class MeteoAlarmWarning {
  const MeteoAlarmWarning({
    required this.id,
    required this.country,
    required this.headline,
    required this.severity,
    required this.urgency,
    required this.certainty,
    required this.areaName,
    required this.effective,
    required this.expires,
    required this.description,
    required this.web,
  });

  final String id;
  final String country;
  final String headline;

  /// 1 = Extreme, 2 = Severe, 3 = Moderate, 4 = Minor (CAP-Konvention invertiert).
  final int severity;
  final String urgency;
  final String certainty;
  final String areaName;
  final DateTime? effective;
  final DateTime? expires;
  final String description;
  final String web;
}

class MeteoAlarmService {
  MeteoAlarmService._();

  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 15);

  /// BUGFIX: Die MeteoAlarm-Legacy-Feeds heißen NICHT nach ISO-Code, sondern
  /// nach vollem englischen Ländernamen (kleingeschrieben). Vorher wurde
  /// 'meteoalarm-legacy-atom-AT' gebaut → 404 für JEDES Land → die
  /// Wetterwarnungen waren immer leer. Diese Map übersetzt ISO → Feed-Slug.
  static const Map<String, String> _feedSlug = {
    'DE': 'germany',
    'AT': 'austria',
    'CH': 'switzerland',
    'IT': 'italy',
    'ES': 'spain',
    'FR': 'france',
    'GB': 'united-kingdom',
    'PL': 'poland',
    'HU': 'hungary',
    'GR': 'greece',
    'PT': 'portugal',
    'NL': 'netherlands',
    'BE': 'belgium',
    'CZ': 'czechia',
    'SK': 'slovakia',
    'SI': 'slovenia',
    'HR': 'croatia',
    'IE': 'ireland',
  };

  /// True wenn für dieses Land ein MeteoAlarm-Feed existiert.
  static bool isSupported(String code) =>
      _feedSlug.containsKey(code.toUpperCase());

  /// Holt Warnungen fuer einen ISO-Country-Code (DE, AT, CH, IT, ES, ...).
  /// Liefert leere Liste bei Netz-Error oder nicht abgedecktem Land.
  static Future<List<MeteoAlarmWarning>> forCountry(String code) async {
    final country = code.toUpperCase();
    final slug = _feedSlug[country];
    if (slug == null) return const [];
    final cached = _cache[country];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _ttl) {
      return cached.data;
    }

    final url = 'https://feeds.meteoalarm.org/feeds/'
        'meteoalarm-legacy-atom-$slug';
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse(url);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'Mensaena/4.0 (+https://www.mensaena.de)');
      req.headers.set('Accept', 'application/atom+xml, application/xml');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return _cache[country]?.data ?? const [];
      }
      final body = await res
          .transform(const _Utf8FallbackDecoder())
          .join()
          .timeout(const Duration(seconds: 8));
      final parsed = _parseAtom(body, country);
      parsed.sort((a, b) => a.severity.compareTo(b.severity));
      _cache[country] = _CacheEntry(parsed);
      return parsed;
    } catch (_) {
      return _cache[country]?.data ?? const [];
    } finally {
      client.close(force: true);
    }
  }

  static void clearCache() => _cache.clear();

  // ---- Parsing ----------------------------------------------------------

  static List<MeteoAlarmWarning> _parseAtom(String body, String country) {
    final result = <MeteoAlarmWarning>[];
    XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } catch (_) {
      return result;
    }

    for (final entry in doc.findAllElements('entry')) {
      final id = _text(entry, 'id');
      final title = _text(entry, 'title');
      final summary = _text(entry, 'summary');
      final updated = DateTime.tryParse(_text(entry, 'updated'))?.toUtc();
      String web = '';
      for (final link in entry.findElements('link')) {
        final href = link.getAttribute('href');
        if (href != null && href.isNotEmpty) {
          web = href;
          break;
        }
      }

      // CAP-Daten liegen entweder als cap:* Elemente oder in Atom-Erweiterungen.
      String? severityRaw;
      String? urgency;
      String? certainty;
      String? areaName;
      String? eventName;
      DateTime? effective;
      DateTime? expires;
      String description = summary;

      // Suche flexibel — feeds.meteoalarm.org nutzt sowohl cap:severity
      // als auch reine Tags ohne Namespace, je nach Quelle.
      for (final el in entry.descendants.whereType<XmlElement>()) {
        final local = el.name.local.toLowerCase();
        final value = el.innerText.trim();
        if (value.isEmpty) continue;
        switch (local) {
          case 'severity':
            severityRaw ??= value;
            break;
          case 'urgency':
            urgency ??= value;
            break;
          case 'certainty':
            certainty ??= value;
            break;
          case 'areadesc':
          case 'area_desc':
            areaName ??= value;
            break;
          case 'event':
            // cap:event z.B. 'Thunderstormwarning' — die eigentliche
            // Warn-Art (Atom-Feeds haben kein <title>).
            eventName ??= value;
            break;
          case 'effective':
          case 'onset':
            effective ??= DateTime.tryParse(value)?.toUtc();
            break;
          case 'expires':
            expires ??= DateTime.tryParse(value)?.toUtc();
            break;
          case 'description':
            if (description.isEmpty) description = value;
            break;
        }
      }

      // Headline-Priorität: Atom-Title → cap:event → Fallback.
      final headline = title.isNotEmpty
          ? title
          : (eventName != null && eventName.isNotEmpty
              ? eventName
              : 'Wetterwarnung');
      final severityInt = _severityToInt(severityRaw ?? _guessFromTitle(title));

      result.add(MeteoAlarmWarning(
        id: id.isNotEmpty ? id : '${country}_${result.length}',
        country: country,
        headline: headline,
        severity: severityInt,
        urgency: urgency ?? '',
        certainty: certainty ?? '',
        areaName: areaName ?? '',
        effective: effective ?? updated,
        expires: expires,
        description: description,
        web: web,
      ));
    }
    return result;
  }

  static String _text(XmlElement parent, String name) {
    final el = parent.findElements(name).firstOrNull;
    return el?.innerText.trim() ?? '';
  }

  /// Map CAP-Severity-String auf int (1=Extreme..4=Minor).
  static int _severityToInt(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('extreme')) return 1;
    if (s.contains('severe')) return 2;
    if (s.contains('moderate')) return 3;
    if (s.contains('minor')) return 4;
    // Manche Feeds liefern "awareness_level" 1-4 (1=gruen ... 4=rot).
    final n = int.tryParse(s);
    if (n != null) {
      // 4=rot=Extreme bei awareness_level, daher invertieren.
      return (5 - n).clamp(1, 4);
    }
    return 3;
  }

  static String _guessFromTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('red')) return 'Extreme';
    if (t.contains('orange')) return 'Severe';
    if (t.contains('yellow')) return 'Moderate';
    if (t.contains('green')) return 'Minor';
    return 'Moderate';
  }
}

class _CacheEntry {
  _CacheEntry(this.data) : timestamp = DateTime.now();
  final List<MeteoAlarmWarning> data;
  final DateTime timestamp;
}

/// Utf8 decoder mit Fallback auf latin1, weil einige nationale Meteo-Feeds
/// ihre Beschreibungen ohne BOM und mit gemischten Encodings ausliefern.
class _Utf8FallbackDecoder extends Converter<List<int>, String> {
  const _Utf8FallbackDecoder();

  @override
  String convert(List<int> input) {
    try {
      return const Utf8Decoder().convert(input);
    } catch (_) {
      return const Latin1Decoder().convert(input);
    }
  }

  @override
  Sink<List<int>> startChunkedConversion(Sink<String> sink) {
    final buf = <int>[];
    return _ByteSink(buf, () {
      sink.add(convert(buf));
      sink.close();
    });
  }
}

class _ByteSink implements Sink<List<int>> {
  _ByteSink(this._buf, this._onClose);
  final List<int> _buf;
  final void Function() _onClose;
  bool _closed = false;

  @override
  void add(List<int> data) {
    if (_closed) return;
    _buf.addAll(data);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _onClose();
  }
}
