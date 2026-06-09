/// SKILL: mensaena-features
/// Civil-Protection-Alerts fuer IT/ES/FR/TR/RU.
///
/// Migration: Die ehemaligen nationalen Direkt-Feeds sind groesstenteils
/// gestorben (alle 404 bzw. CMS-Migration zu SPAs ohne RSS):
///   - protezionecivile.gov.it/feed/comunicati  → 404 (Site jetzt React-SPA)
///   - proteccioncivil.es/feeds/avisos.xml      → 404 (CMS-Wechsel)
///   - vigilance.meteofrance.fr/data/...xml     → 404 (HTML-Wrapper nur)
///   - afad.gov.tr/rss/duyurular.xml            → 404 (Layout-Refresh)
///
/// Neue Strategie: Wir nutzen die paneuropaeischen MeteoAlarm-Feeds
/// (https://feeds.meteoalarm.org) als verlaesslichen Ersatz fuer IT/ES/FR.
/// Diese Feeds sind im offiziellen CAP-Format und werden von genau den
/// nationalen Wetterdiensten gespeist, die fuer Naturgefahren-Warnungen
/// zustaendig sind. Fuer RU laeuft МЧС RSS weiter (✅ funktioniert). Fuer
/// TR fehlt es einen stabilen offiziellen Feed — wir nutzen die Kandilli
/// Observatory Earthquake-Liste (KOERI Bogazici) als Erdbeben-Warnsignal.
///
/// Quellen (Stand 2026-05):
///  - IT  MeteoAlarm Italien
///  - ES  MeteoAlarm Spanien
///  - FR  MeteoAlarm Frankreich
///  - TR  Kandilli Observatory (Erdbeben)
///  - RU  МЧС России (RSS funktioniert weiterhin)
///
/// 15 Min Memory-Cache, Fail-Silent (leere Liste bei Netzfehler).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../repositories/extra_repositories.dart';

class CivilProtectionAlert {
  const CivilProtectionAlert({
    required this.id,
    required this.country,
    required this.title,
    required this.description,
    required this.link,
    required this.publishedAt,
    required this.source,
  });

  final String id;
  final String country;
  final String title;
  final String description;
  final String link;
  final DateTime? publishedAt;
  final String source;
}

class CivilProtectionService {
  CivilProtectionService._();

  static const Map<String, _FeedConfig> _feeds = {
    'IT': _FeedConfig(
      url:
          'https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-italy',
      source: 'MeteoAlarm Italy',
    ),
    'ES': _FeedConfig(
      url:
          'https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-spain',
      source: 'MeteoAlarm Spain',
    ),
    'FR': _FeedConfig(
      url:
          'https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-france',
      source: 'MeteoAlarm France',
    ),
    'TR': _FeedConfig(
      // Kandilli Observatory: HTML-Seite mit Erdbeben-Liste der letzten Tage.
      // Wird im Parser per Heuristik in Items zerlegt — siehe _parseKandilli().
      url: 'http://www.koeri.boun.edu.tr/scripts/lst0.asp',
      source: 'Kandilli Observatory',
    ),
    'RU': _FeedConfig(
      url: 'https://www.mchs.gov.ru/rss/news.xml',
      source: 'МЧС России',
    ),
  };

  static const Set<String> supportedCountries = {'IT', 'ES', 'FR', 'TR', 'RU'};

  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(minutes: 15);

  /// True wenn das Land einen nationalen Civil-Protection-Feed hat.
  static bool isSupported(String code) =>
      _feeds.containsKey(code.toUpperCase());

  /// Source-Label (z.B. fuer Disclaimer/Fallback-Cards).
  static String sourceLabel(String code) =>
      _feeds[code.toUpperCase()]?.source ?? '';

  /// Holt Alerts fuer ein Land. Liefert leere Liste bei Netz-/Parse-Fehler.
  static Future<List<CivilProtectionAlert>> forCountry(String code) async {
    final country = code.toUpperCase();
    final cfg = _feeds[country];
    if (cfg == null) return const [];

    final cached = _cache[country];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _ttl) {
      return cached.data;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse(cfg.url);
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'Mensaena/4.0 (+https://www.mensaena.de)');
      req.headers.set(
          'Accept', 'application/rss+xml, application/xml, text/xml, */*');
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        // ignore: discarded_futures
        ErrorLogsRepository.log(
          errorType: 'civil_protection_http_${res.statusCode}',
          message: 'GET ${cfg.url} -> ${res.statusCode}',
        );
        return _cache[country]?.data ?? const [];
      }
      final body = await res
          .transform(const _Utf8FallbackDecoder())
          .join()
          .timeout(const Duration(seconds: 8));
      final parsed = _parse(body, country, cfg.source);
      _cache[country] = _CacheEntry(parsed);
      return parsed;
    } catch (e, st) {
      // ignore: discarded_futures
      ErrorLogsRepository.log(
        errorType: 'civil_protection_fetch_failed',
        message: 'country=$country url=${cfg.url} err=$e',
        stack: st.toString(),
      );
      return _cache[country]?.data ?? const [];
    } finally {
      client.close(force: true);
    }
  }

  static void clearCache() => _cache.clear();

  // ---- Parsing ----------------------------------------------------------

  static List<CivilProtectionAlert> _parse(
    String body,
    String country,
    String source,
  ) {
    // Sonderfall TR: Kandilli liefert kein XML sondern eine HTML-Seite mit
    // fixed-width Erdbeben-Tabelle in <pre>. Parser ist eigen.
    if (country == 'TR' && body.contains('<pre>')) {
      return _parseKandilli(body, source);
    }

    XmlDocument doc;
    try {
      doc = XmlDocument.parse(body);
    } catch (_) {
      return const [];
    }

    // RSS 2.0 (<rss><channel><item>) — IT / ES / TR / RU
    final items = doc.findAllElements('item').toList();
    if (items.isNotEmpty) {
      return _parseRss(items, country, source);
    }

    // Atom (<feed><entry>) — MeteoAlarm IT/ES/FR seit 2026 (siehe oben)
    final entries = doc.findAllElements('entry').toList();
    if (entries.isNotEmpty) {
      return _parseAtom(entries, country, source);
    }

    // CAP (alte Meteo-France Vigilance + andere CAP-1.2-Feeds).
    final infos = doc.findAllElements('info').toList();
    if (infos.isNotEmpty) {
      return _parseCap(infos, country, source);
    }

    return const [];
  }

  /// Kandilli Observatory (TR) — keine RSS, sondern HTML-Tabelle in <pre>.
  /// Format pro Zeile (fixed-width, Leerzeichen-getrennt):
  ///   YYYY.MM.DD HH:MM:SS  LAT     LNG     DEPTH  MD  ML  Mw   LOCATION  SOLUTION
  /// Wir filtern auf Mag >= 3.0 (alles darunter ist meist nicht spuerbar).
  static List<CivilProtectionAlert> _parseKandilli(
      String body, String source) {
    // <pre>-Block extrahieren.
    final preMatch =
        RegExp(r'<pre>(.*?)</pre>', dotAll: true, caseSensitive: false)
            .firstMatch(body);
    if (preMatch == null) return const [];
    final pre = preMatch.group(1) ?? '';
    // Zeilen die mit YYYY.MM.DD beginnen.
    final lineRe = RegExp(
      r'^(\d{4}\.\d{2}\.\d{2})\s+(\d{2}:\d{2}:\d{2})\s+'
      r'(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+'
      r'([-.\d]+)\s+([-.\d]+)\s+([-.\d]+)\s+(.+?)\s{2,}',
      multiLine: true,
    );
    final out = <CivilProtectionAlert>[];
    for (final m in lineRe.allMatches(pre)) {
      final date = m.group(1)!.replaceAll('.', '-');
      final time = m.group(2)!;
      final lat = double.tryParse(m.group(3) ?? '');
      final lng = double.tryParse(m.group(4) ?? '');
      final depth = double.tryParse(m.group(5) ?? '');
      // 3 Magnitude-Spalten: MD, ML, Mw — wir nehmen die hoechste.
      double? bestMag;
      for (final raw in [m.group(6), m.group(7), m.group(8)]) {
        final cleaned = raw?.replaceAll(RegExp(r'[^\d.]'), '');
        final v = double.tryParse(cleaned ?? '');
        if (v != null && v > 0 && (bestMag == null || v > bestMag)) {
          bestMag = v;
        }
      }
      if (bestMag == null || bestMag < 3.0) continue;
      final location = m.group(9)?.trim() ?? '';
      final dt = DateTime.tryParse('${date}T${time}Z')?.toUtc();
      out.add(CivilProtectionAlert(
        id: 'TR_kandilli_${date}_$time',
        country: 'TR',
        title: 'M ${bestMag.toStringAsFixed(1)} · $location',
        description: depth != null
            ? 'Erdbeben — Tiefe ${depth.toStringAsFixed(1)} km'
                ' · ${lat?.toStringAsFixed(2)},${lng?.toStringAsFixed(2)}'
            : 'Erdbeben',
        link: 'http://www.koeri.boun.edu.tr/scripts/lst0.asp',
        publishedAt: dt,
        source: source,
      ));
      if (out.length >= 30) break;
    }
    return out;
  }

  static List<CivilProtectionAlert> _parseRss(
    List<XmlElement> items,
    String country,
    String source,
  ) {
    final out = <CivilProtectionAlert>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final title = _firstText(item, ['title']);
      final link = _firstText(item, ['link', 'guid']);
      final desc = _stripHtml(_firstText(item, ['description', 'summary']));
      final pubRaw = _firstText(item, ['pubDate', 'published', 'date']);
      final pub = _parseDate(pubRaw);
      final id = _firstText(item, ['guid']);
      out.add(CivilProtectionAlert(
        id: id.isNotEmpty ? id : '${country}_rss_$i',
        country: country,
        title: title.isNotEmpty ? title : source,
        description: desc,
        link: link,
        publishedAt: pub,
        source: source,
      ));
    }
    return out;
  }

  static List<CivilProtectionAlert> _parseAtom(
    List<XmlElement> entries,
    String country,
    String source,
  ) {
    final out = <CivilProtectionAlert>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final title = _firstText(entry, ['title']);
      final id = _firstText(entry, ['id']);
      final desc =
          _stripHtml(_firstText(entry, ['summary', 'content', 'description']));
      final pub = _parseDate(_firstText(entry, ['updated', 'published']));
      String link = '';
      for (final l in entry.findElements('link')) {
        final href = l.getAttribute('href');
        if (href != null && href.isNotEmpty) {
          link = href;
          break;
        }
      }
      out.add(CivilProtectionAlert(
        id: id.isNotEmpty ? id : '${country}_atom_$i',
        country: country,
        title: title.isNotEmpty ? title : source,
        description: desc,
        link: link,
        publishedAt: pub,
        source: source,
      ));
    }
    return out;
  }

  static List<CivilProtectionAlert> _parseCap(
    List<XmlElement> infos,
    String country,
    String source,
  ) {
    final out = <CivilProtectionAlert>[];
    for (var i = 0; i < infos.length; i++) {
      final info = infos[i];
      final title = _firstText(info, ['event', 'headline']);
      final desc = _stripHtml(_firstText(info, ['description', 'instruction']));
      final web = _firstText(info, ['web']);
      final eff = _parseDate(_firstText(info, ['effective', 'onset']));
      out.add(CivilProtectionAlert(
        id: '${country}_cap_$i',
        country: country,
        title: title.isNotEmpty ? title : source,
        description: desc,
        link: web,
        publishedAt: eff,
        source: source,
      ));
    }
    return out;
  }

  static String _firstText(XmlElement parent, List<String> names) {
    for (final n in names) {
      final el = parent.findElements(n).firstOrNull;
      if (el != null) {
        final v = el.innerText.trim();
        if (v.isNotEmpty) return v;
      }
    }
    return '';
  }

  static String _stripHtml(String raw) {
    if (raw.isEmpty) return raw;
    final noTags = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final unescaped = noTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    return unescaped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw)?.toUtc();
    if (iso != null) return iso;
    // RFC 822 (z.B. "Mon, 04 Mar 2026 15:30:00 +0100") — defensiv.
    try {
      return HttpDate.parse(raw);
    } catch (_) {
      return null;
    }
  }
}

class _FeedConfig {
  const _FeedConfig({required this.url, required this.source});
  final String url;
  final String source;
}

class _CacheEntry {
  _CacheEntry(this.data) : timestamp = DateTime.now();
  final List<CivilProtectionAlert> data;
  final DateTime timestamp;
}

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
