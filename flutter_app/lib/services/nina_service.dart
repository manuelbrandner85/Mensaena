import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import '../config/env.dart';

/// SKILL: mensaena-architektur
/// NINA-Warn-API (Bundesamt fuer Bevoelkerungsschutz und Katastrophenhilfe).
/// Primary + Fallback URL, 15min in-memory Cache, 8s Timeout.
class NinaService {
  NinaService._();
  static final NinaService instance = NinaService._();

  final _cache = <String, _CacheEntry>{};

  /// Liste aller aktiven Warnungen fuer einen AGS (Gemeindeschluessel).
  /// AGS=000000000000 = bundesweit.
  Future<List<Map<String, dynamic>>> fetchDashboard({
    String ags = AppConfig.defaultAgs,
  }) async {
    final cacheKey = 'dashboard/$ags';
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    final data = await _fetchWithFallback('dashboard/$ags.json');
    if (data is List) {
      final result = data.whereType<Map<String, dynamic>>().toList();
      result.sort(_severitySort);
      _cache[cacheKey] = _CacheEntry(result);
      return result;
    }
    return const [];
  }

  /// Detail-Daten fuer eine konkrete Warn-ID.
  Future<Map<String, dynamic>?> fetchWarningDetail(String warnId) async {
    final data = await _fetchWithFallback('warnings/$warnId.json');
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<dynamic> _fetchWithFallback(String path) async {
    final urls = [Env.ninaPrimary, Env.ninaFallback];
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      for (final base in urls) {
        try {
          final uri = Uri.parse('$base/$path');
          final req = await client.getUrl(uri);
          req.headers.set('User-Agent', 'Mensaena/4.0');
          final res = await req.close().timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            final body = await res.transform(utf8.decoder).join();
            return jsonDecode(body);
          }
        } catch (_) {
          // try next URL
        }
      }
    } finally {
      client.close(force: true);
    }
    return null;
  }

  /// Severity sort: Extreme > Severe > Moderate > Minor.
  static int _severitySort(Map<String, dynamic> a, Map<String, dynamic> b) {
    const order = {'Extreme': 0, 'Severe': 1, 'Moderate': 2, 'Minor': 3};
    final sa = order[(a['severity'] ?? 'Minor').toString()] ?? 4;
    final sb = order[(b['severity'] ?? 'Minor').toString()] ?? 4;
    return sa.compareTo(sb);
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry {
  _CacheEntry(this.data) : timestamp = DateTime.now();
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;
  bool get isExpired =>
      DateTime.now().difference(timestamp).inSeconds >
      AppConfig.ninaCacheTtlSec;
}
