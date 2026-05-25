/// SKILL: mensaena-features
/// NASA Astronomy Picture of the Day. Gratis-API mit DEMO_KEY
/// (30 calls/hour, 50/day pro IP). Fuer 1 Widget mehr als genug.
/// https://api.nasa.gov/planetary/apod
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class NasaApod {
  const NasaApod({
    required this.date,
    required this.title,
    required this.explanation,
    required this.url,
    this.hdUrl,
    this.copyright,
    this.mediaType = 'image',
  });

  final String date;
  final String title;
  final String explanation;
  final String url;
  final String? hdUrl;
  final String? copyright;
  final String mediaType;

  Map<String, dynamic> toJson() => {
        'date': date,
        'title': title,
        'explanation': explanation,
        'url': url,
        'hdurl': hdUrl,
        'copyright': copyright,
        'media_type': mediaType,
      };

  factory NasaApod.fromJson(Map<String, dynamic> j) => NasaApod(
        date: j['date'] as String? ?? '',
        title: j['title'] as String? ?? '',
        explanation: j['explanation'] as String? ?? '',
        url: j['url'] as String? ?? '',
        hdUrl: j['hdurl'] as String?,
        copyright: j['copyright'] as String?,
        mediaType: (j['media_type'] as String?) ?? 'image',
      );
}

class NasaApodService {
  const NasaApodService._();

  static const _storage = FlutterSecureStorage();
  static const _cacheKey = 'mensaena_nasa_apod_v1';
  static const _cacheDateKey = 'mensaena_nasa_apod_date_v1';

  /// Liefert das APOD des heutigen Tages. Cache 24h via secure_storage.
  /// API: api.nasa.gov mit DEMO_KEY (50 calls/day genug fuer 1 Widget).
  static Future<NasaApod?> today() async {
    final today = _dateString(DateTime.now().toUtc());
    try {
      final cachedDate = await _storage.read(key: _cacheDateKey);
      if (cachedDate == today) {
        final cachedRaw = await _storage.read(key: _cacheKey);
        if (cachedRaw != null && cachedRaw.isNotEmpty) {
          final cached = json.decode(cachedRaw) as Map<String, dynamic>;
          return NasaApod.fromJson(cached);
        }
      }
    } catch (_) {/* corrupt cache → neu fetchen */}

    try {
      final r = await http
          .get(Uri.parse('https://api.nasa.gov/planetary/apod?api_key=DEMO_KEY'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return _readStaleCache();
      final j = json.decode(r.body) as Map<String, dynamic>;
      final apod = NasaApod.fromJson(j);
      try {
        await _storage.write(key: _cacheKey, value: json.encode(apod.toJson()));
        await _storage.write(key: _cacheDateKey, value: today);
      } catch (_) {}
      return apod;
    } catch (e) {
      debugPrint('[NasaApod] failed: $e');
      return _readStaleCache();
    }
  }

  static Future<NasaApod?> _readStaleCache() async {
    try {
      final raw = await _storage.read(key: _cacheKey);
      if (raw == null) return null;
      return NasaApod.fromJson(json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static String _dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
