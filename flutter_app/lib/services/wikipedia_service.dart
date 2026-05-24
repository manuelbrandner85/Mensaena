/// SKILL: mensaena-features
/// Wikipedia REST Summary API — kostenlos, kein API-Key.
/// https://en.wikipedia.org/api/rest_v1/page/summary/{term}
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

class WikiSummary {
  const WikiSummary({
    required this.title,
    required this.extract,
    required this.url,
    this.thumbnailUrl,
    this.description,
  });

  final String title;
  final String extract;
  final String url;
  final String? thumbnailUrl;
  final String? description;
}

class WikipediaService {
  const WikipediaService._();

  /// Lookup-Such-Term in der gewünschten Wiki-Sprache.
  /// [lang] z. B. 'de', 'en', 'it'.
  static Future<WikiSummary?> summary(String term, {String lang = 'de'}) async {
    final q = Uri.encodeComponent(term.trim());
    if (q.isEmpty) return null;
    try {
      final uri = Uri.parse(
          'https://$lang.wikipedia.org/api/rest_v1/page/summary/$q');
      final r = await http.get(uri, headers: {
        'User-Agent': 'Mensaena/1.0 (https://mensaena.de)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = json.decode(r.body) as Map<String, dynamic>;
      final extract = j['extract'] as String?;
      if (extract == null || extract.isEmpty) return null;
      return WikiSummary(
        title: j['title'] as String? ?? term,
        extract: extract,
        url: ((j['content_urls'] as Map?)?['desktop'] as Map?)?['page']
                as String? ??
            'https://$lang.wikipedia.org/wiki/$q',
        thumbnailUrl: (j['thumbnail'] as Map?)?['source'] as String?,
        description: j['description'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
