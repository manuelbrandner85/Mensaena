/// SKILL: mensaena-features
/// BooksService — Bücher-Empfehlungen via Open Library.
///
/// Datenquelle: https://openlibrary.org/search.json
/// — komplett offen, kein API-Key. Wir holen Bücher zum Thema
/// Nachhaltigkeit + Gemeinschaft. Cache 24h via flutter_secure_storage.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class BookRec {
  const BookRec({
    required this.key,
    required this.title,
    required this.authorName,
    required this.coverId,
    required this.firstPublishYear,
  });

  final String key; // /works/OL...W
  final String title;
  final String authorName;
  final int? coverId;
  final int? firstPublishYear;

  String? get coverUrl => coverId == null
      ? null
      : 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'authorName': authorName,
        'coverId': coverId,
        'firstPublishYear': firstPublishYear,
      };

  factory BookRec.fromJson(Map<String, dynamic> j) => BookRec(
        key: j['key'] as String? ?? '',
        title: j['title'] as String? ?? '',
        authorName: j['authorName'] as String? ?? '',
        coverId: (j['coverId'] as num?)?.toInt(),
        firstPublishYear: (j['firstPublishYear'] as num?)?.toInt(),
      );
}

class BooksService {
  const BooksService._();

  static const _storage = FlutterSecureStorage();
  static const _cacheKey = 'mensaena_books_cache_v1';
  static const _cacheAtKey = 'mensaena_books_cache_at_v1';
  static const _ttl = Duration(hours: 24);

  /// Liefert ~6 Buch-Empfehlungen. Cache wird gelesen wenn juenger als
  /// 24h. Bei Netzwerkfehler: cached value (auch wenn alt) oder leere
  /// Liste.
  static Future<List<BookRec>> recommendations({String? locale}) async {
    final lang = (locale ?? 'de').substring(0, 2);
    try {
      final atRaw = await _storage.read(key: _cacheAtKey);
      final at = atRaw == null ? null : DateTime.tryParse(atRaw);
      if (at != null && DateTime.now().difference(at) < _ttl) {
        final raw = await _storage.read(key: _cacheKey);
        if (raw != null && raw.isNotEmpty) {
          final list = (jsonDecode(raw) as List)
              .cast<Map<String, dynamic>>()
              .map(BookRec.fromJson)
              .toList();
          if (list.isNotEmpty) return list;
        }
      }
    } catch (_) {/* corrupt cache — neu fetchen */}

    final query = lang == 'de'
        ? 'nachhaltigkeit gemeinschaft permakultur'
        : 'sustainability community permaculture';
    try {
      final uri = Uri.parse(
          'https://openlibrary.org/search.json?q=${Uri.encodeQueryComponent(query)}&limit=6&lang=$lang');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return _readCacheStale();
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final docs = (j['docs'] as List?) ?? const [];
      final out = <BookRec>[];
      for (final d in docs.take(6)) {
        if (d is! Map) continue;
        final authors = (d['author_name'] as List?) ?? const [];
        out.add(BookRec(
          key: (d['key'] as String?) ?? '',
          title: (d['title'] as String?) ?? '',
          authorName:
              authors.isEmpty ? '' : (authors.first as String? ?? ''),
          coverId: (d['cover_i'] as num?)?.toInt(),
          firstPublishYear: (d['first_publish_year'] as num?)?.toInt(),
        ));
      }
      try {
        await _storage.write(
            key: _cacheKey, value: jsonEncode(out.map((b) => b.toJson()).toList()));
        await _storage.write(
            key: _cacheAtKey, value: DateTime.now().toIso8601String());
      } catch (_) {}
      return out;
    } catch (e) {
      debugPrint('[BooksService] failed: $e');
      return _readCacheStale();
    }
  }

  static Future<List<BookRec>> _readCacheStale() async {
    try {
      final raw = await _storage.read(key: _cacheKey);
      if (raw == null || raw.isEmpty) return const <BookRec>[];
      return (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(BookRec.fromJson)
          .toList();
    } catch (_) {
      return const <BookRec>[];
    }
  }
}
