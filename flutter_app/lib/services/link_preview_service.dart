import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/link_preview.dart';

/// Zieht Open-Graph / Twitter-Meta-Tags aus dem `<head>` einer URL und
/// liefert eine [LinkPreview]. In-Memory gecached, damit eine URL pro
/// Session nur einmal gefetcht wird.
///
/// Keine externen Dienste — direkter HTTP-Fetch mit generischem User-Agent
/// (viele CDNs blocken Dart-Default-UA).
///
/// Adaptiert aus Weltenbibliothek-App (manuelbrandner85/Weltenbibliothekapp,
/// lib/services/chat/link_preview_service.dart). Identische Logik mit
/// Mensaena-User-Agent.
class LinkPreviewService {
  LinkPreviewService._();
  static final LinkPreviewService instance = LinkPreviewService._();

  static const Duration _timeout = Duration(seconds: 6);
  static const int _maxBytes = 262144; // 256 KB reichen fürs <head>
  // Mensaena-eigener UA-Suffix für Server-Logs — Dart-Default-UA wird von
  // vielen CDNs blockiert, daher Mobile-Chrome-Profil als Basis.
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 '
      'Mensaena/1.0 (+https://www.mensaena.de)';

  final Map<String, LinkPreview?> _cache = <String, LinkPreview?>{};
  final Map<String, Future<LinkPreview?>> _inflight =
      <String, Future<LinkPreview?>>{};

  static final RegExp _urlRegex = RegExp(
    r'https?:\/\/[^\s<>()"]+',
    caseSensitive: false,
  );

  /// Erste HTTP/HTTPS-URL in [text] oder null.
  static String? firstUrl(String text) {
    final m = _urlRegex.firstMatch(text);
    if (m == null) return null;
    var u = m.group(0)!;
    // Trailing Satzzeichen abschneiden (häufig am Ende von Sätzen)
    while (u.isNotEmpty && '.,;:!?)]}'.contains(u[u.length - 1])) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Gibt den In-Memory-Cache komplett frei (RAM-Reset). Aufruf vom
  /// MemoryWatchdog bei Speicherdruck — laufende Fetches (`_inflight`)
  /// laufen unangetastet weiter und cachen ihr Ergebnis neu.
  void clearCache() => _cache.clear();

  /// Preview für [url] holen. Synchroner Cache-Hit liefert sofort, sonst
  /// läuft der Fetch im Hintergrund und bei Fertigstellung pusht der Caller
  /// via Rebuild.
  LinkPreview? cached(String url) => _cache[url];

  Future<LinkPreview?> fetch(String url) {
    if (_cache.containsKey(url)) return Future.value(_cache[url]);
    final inflight = _inflight[url];
    if (inflight != null) return inflight;

    final fut = _doFetch(url).whenComplete(() {
      _inflight.remove(url);
    });
    _inflight[url] = fut;
    return fut;
  }

  Future<LinkPreview?> _doFetch(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasAuthority) {
        _cache[url] = null;
        return null;
      }
      final res = await http.get(
        uri,
        headers: <String, String>{
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(_timeout);

      if (res.statusCode < 200 || res.statusCode >= 400) {
        _cache[url] = null;
        return null;
      }

      // Nur das erste Stück — <head> reicht.
      final body = res.body.length > _maxBytes
          ? res.body.substring(0, _maxBytes)
          : res.body;

      final preview =
          _parse(url: url, html: body, finalUri: res.request?.url ?? uri);
      _cache[url] = preview;
      return preview;
    } catch (e) {
      if (kDebugMode) debugPrint('[LinkPreview] fetch failed for $url: $e');
      _cache[url] = null;
      return null;
    }
  }

  LinkPreview? _parse({
    required String url,
    required String html,
    required Uri finalUri,
  }) {
    final head = _extractHead(html);
    if (head == null) return null;

    String? ogTitle = _meta(head, property: 'og:title');
    String? ogDesc = _meta(head, property: 'og:description');
    String? ogImg = _meta(head, property: 'og:image');
    final String? ogSite = _meta(head, property: 'og:site_name');

    ogTitle ??= _meta(head, name: 'twitter:title');
    ogDesc ??= _meta(head, name: 'twitter:description');
    ogImg ??= _meta(head, name: 'twitter:image');

    ogTitle ??= _titleTag(head);
    ogDesc ??= _meta(head, name: 'description');

    final absImg = ogImg != null ? _absolute(finalUri, ogImg) : null;

    final preview = LinkPreview(
      url: url,
      title: _clean(ogTitle),
      description: _clean(ogDesc),
      imageUrl: absImg,
      siteName: _clean(ogSite) ?? finalUri.host,
    );
    return preview.hasContent ? preview : null;
  }

  String? _extractHead(String html) {
    final lower = html.toLowerCase();
    final start = lower.indexOf('<head');
    final end = lower.indexOf('</head>');
    if (start == -1 || end == -1 || end <= start) {
      // Manche Seiten liefern Meta-Tags ausserhalb — nimm den ganzen String.
      return html.length > 16384 ? html.substring(0, 16384) : html;
    }
    return html.substring(start, end + 7);
  }

  String? _meta(String head, {String? property, String? name}) {
    RegExp regex;
    if (property != null) {
      regex = RegExp(
        r'<meta[^>]+property\s*=\s*["\x27]' +
            RegExp.escape(property) +
            r'["\x27][^>]*>',
        caseSensitive: false,
      );
    } else {
      regex = RegExp(
        r'<meta[^>]+name\s*=\s*["\x27]' +
            RegExp.escape(name!) +
            r'["\x27][^>]*>',
        caseSensitive: false,
      );
    }
    final tag = regex.firstMatch(head)?.group(0);
    if (tag == null) return null;
    final contentMatch = RegExp(
      r'content\s*=\s*["\x27]([^"\x27]*)["\x27]',
      caseSensitive: false,
    ).firstMatch(tag);
    return contentMatch?.group(1);
  }

  String? _titleTag(String head) {
    final m = RegExp(r'<title[^>]*>(.*?)</title>',
            caseSensitive: false, dotAll: true)
        .firstMatch(head);
    return m?.group(1);
  }

  String? _clean(String? s) {
    if (s == null) return null;
    final t = s
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
    return t.isEmpty ? null : t;
  }

  String? _absolute(Uri base, String url) {
    final u = url.trim();
    if (u.isEmpty) return null;
    try {
      final parsed = Uri.parse(u);
      if (parsed.hasScheme) return parsed.toString();
      return base.resolve(u).toString();
    } catch (_) {
      return null;
    }
  }
}
