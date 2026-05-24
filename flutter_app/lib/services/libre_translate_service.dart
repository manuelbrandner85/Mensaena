/// SKILL: mensaena-features
/// LibreTranslate — kostenfreie Public-Instance.
/// https://libretranslate.com — wir nutzen Mirror (.de hat strikteres Rate-Limit).
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

const List<String> _instances = [
  'https://libretranslate.de',
  'https://translate.argosopentech.com',
  'https://translate.fortytwo-it.com',
];

class TranslationResult {
  const TranslationResult({
    required this.text,
    required this.detectedSource,
    this.confidence,
  });

  final String text;
  final String detectedSource;
  final double? confidence;
}

class LibreTranslateService {
  const LibreTranslateService._();

  /// Übersetzt Text. [source] = 'auto' für Auto-Detect.
  static Future<TranslationResult?> translate({
    required String text,
    required String target,
    String source = 'auto',
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    for (final base in _instances) {
      try {
        final uri = Uri.parse('$base/translate');
        final r = await http.post(uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'q': clean,
              'source': source,
              'target': target,
              'format': 'text',
            })).timeout(const Duration(seconds: 10));
        if (r.statusCode != 200) continue;
        final j = json.decode(r.body) as Map<String, dynamic>;
        final translated = j['translatedText'] as String?;
        if (translated == null) continue;
        final det = (j['detectedLanguage'] as Map<String, dynamic>?);
        return TranslationResult(
          text: translated,
          detectedSource: det?['language'] as String? ?? source,
          confidence: (det?['confidence'] as num?)?.toDouble(),
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
