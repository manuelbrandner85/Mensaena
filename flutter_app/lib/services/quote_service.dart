/// SKILL: mensaena-features
/// Daily Quote via ZenQuotes API. Gratis, kein Key, 1 Request/Tag noetig.
/// https://zenquotes.io/api/today
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class Quote {
  const Quote({required this.text, required this.author});
  final String text;
  final String author;

  Map<String, dynamic> toJson() => {'q': text, 'a': author};
  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        text: j['q'] as String? ?? '',
        author: j['a'] as String? ?? '',
      );
}

class QuoteService {
  const QuoteService._();

  static const _storage = FlutterSecureStorage();
  static const _cacheKey = 'mensaena_quote_cache_v1';
  static const _cacheDateKey = 'mensaena_quote_date_v1';

  /// Liefert das Zitat des Tages. Cache pro Kalendertag in
  /// flutter_secure_storage — schont das Limit von ZenQuotes (5 req/30s).
  static Future<Quote?> fetchDaily() async {
    final today = _dateString(DateTime.now());
    try {
      final cachedDate = await _storage.read(key: _cacheDateKey);
      if (cachedDate == today) {
        final raw = await _storage.read(key: _cacheKey);
        if (raw != null && raw.isNotEmpty) {
          return Quote.fromJson(json.decode(raw) as Map<String, dynamic>);
        }
      }
    } catch (_) {/* corrupt cache → neu fetchen */}

    try {
      final r = await http
          .get(Uri.parse('https://zenquotes.io/api/today'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return _readStaleCache();
      final list = json.decode(r.body) as List;
      if (list.isEmpty) return _readStaleCache();
      final q = Quote.fromJson((list.first as Map).cast<String, dynamic>());
      if (q.text.isEmpty) return _readStaleCache();
      try {
        await _storage.write(key: _cacheKey, value: json.encode(q.toJson()));
        await _storage.write(key: _cacheDateKey, value: today);
      } catch (_) {}
      return q;
    } catch (e) {
      debugPrint('[QuoteService] fetch failed: $e');
      return _readStaleCache();
    }
  }

  static Future<Quote?> _readStaleCache() async {
    try {
      final raw = await _storage.read(key: _cacheKey);
      if (raw == null) return null;
      return Quote.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static String _dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
