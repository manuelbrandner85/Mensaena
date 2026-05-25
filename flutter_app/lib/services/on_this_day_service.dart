/// SKILL: mensaena-features
/// Wikipedia "On This Day" — historische Ereignisse fuer den aktuellen Tag.
/// https://en.wikipedia.org/api/rest_v1/feed/onthisday/selected/{MM}/{DD}
/// Auch DE-Variante: de.wikipedia.org/api/rest_v1/feed/onthisday/...
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class OnThisDayEvent {
  const OnThisDayEvent({
    required this.year,
    required this.text,
    this.thumbnail,
    this.articleUrl,
  });

  final int year;
  final String text;
  final String? thumbnail;
  final String? articleUrl;
}

class OnThisDayService {
  const OnThisDayService._();

  static List<OnThisDayEvent>? _memoryCache;
  static String? _memoryDate;

  /// Heutige "On this day"-Events. Max 6 Stueck (vom Service mit hoechster
  /// Pageview-Zahl auf Wikipedia bevorzugt). Cache im Memory pro Datum.
  static Future<List<OnThisDayEvent>> today({String lang = 'de'}) async {
    final now = DateTime.now().toUtc();
    final dateKey = '$lang-${now.month}-${now.day}';
    if (_memoryCache != null && _memoryDate == dateKey) {
      return _memoryCache!;
    }
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    // DE-Wiki hat "On This Day" nur fuer EN sauber. Wir nehmen DE wenn
    // verfuegbar und fallen sonst auf EN zurueck.
    final urls = lang == 'de'
        ? [
            'https://de.wikipedia.org/api/rest_v1/feed/onthisday/selected/$mm/$dd',
            'https://en.wikipedia.org/api/rest_v1/feed/onthisday/selected/$mm/$dd',
          ]
        : ['https://en.wikipedia.org/api/rest_v1/feed/onthisday/selected/$mm/$dd'];
    for (final url in urls) {
      try {
        final r = await http
            .get(Uri.parse(url),
                headers: {'User-Agent': 'Mensaena/4.0 (de.mensaena.app)'})
            .timeout(const Duration(seconds: 8));
        if (r.statusCode != 200) continue;
        final j = json.decode(r.body) as Map<String, dynamic>;
        final selected = j['selected'] as List? ?? const [];
        final events = <OnThisDayEvent>[];
        for (final raw in selected.whereType<Map<String, dynamic>>().take(6)) {
          final pages = raw['pages'] as List? ?? const [];
          final firstPage =
              pages.whereType<Map<String, dynamic>>().firstOrNull;
          final thumbnail =
              (firstPage?['thumbnail'] as Map<String, dynamic>?)?['source']
                  as String?;
          final articleUrl = (firstPage?['content_urls']
                  as Map<String, dynamic>?)?['desktop']?['page'] as String?;
          events.add(OnThisDayEvent(
            year: (raw['year'] as num?)?.toInt() ?? 0,
            text: (raw['text'] as String?) ?? '',
            thumbnail: thumbnail,
            articleUrl: articleUrl,
          ));
        }
        if (events.isNotEmpty) {
          _memoryCache = events;
          _memoryDate = dateKey;
          return events;
        }
      } catch (e) {
        debugPrint('[OnThisDay] $url failed: $e');
        continue;
      }
    }
    return const [];
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
