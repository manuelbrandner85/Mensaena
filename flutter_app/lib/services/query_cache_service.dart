/// SKILL: mensaena-features (Performance P15)
/// In-Memory-Cache für selten-ändernde Daten. Reduziert redundante
/// Supabase-Queries bei häufig besuchten Screens.
///
/// Verwendung:
///   final cached = QueryCache.get<Profile>('profile_$uid');
///   if (cached != null) return cached;
///   final p = await sb.from('profiles').select(...).single();
///   QueryCache.set('profile_$uid', Profile.fromJson(p));
///
/// IMMER invalidieren wenn Daten geändert werden:
///   QueryCache.invalidate('profile_$uid');  // nach Profile-Update
///   QueryCache.invalidateAll();             // bei Logout
library;

class _CacheEntry {
  _CacheEntry(this.data, this.timestamp);
  final dynamic data;
  final DateTime timestamp;
}

class QueryCache {
  QueryCache._();
  static final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

  /// Liefert gecached'tes Item zurück oder null wenn TTL abgelaufen / nicht vorhanden.
  static T? get<T>(String key, {Duration ttl = const Duration(minutes: 5)}) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > ttl) {
      _cache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  /// Schreibt einen neuen Cache-Eintrag (TS = jetzt).
  static void set(String key, dynamic data) {
    _cache[key] = _CacheEntry(data, DateTime.now());
  }

  /// Cache-fähige Daten + ihre empfohlenen TTLs (für Konsistenz im Code).
  static const Duration ttlProfile = Duration(minutes: 5);
  static const Duration ttlBadges = Duration(minutes: 30);
  static const Duration ttlEmergencyNumbers = Duration(hours: 24);
  static const Duration ttlOrganizations = Duration(minutes: 15);
  static const Duration ttlNotifPrefs = Duration(minutes: 10);
  static const Duration ttlDashboardConfig = Duration(minutes: 10);

  /// Convenience: wrapper "lade oder fetch".
  /// Achtung: fetcher MUSS erfolgreich sein, sonst wird Cache nicht gefüllt.
  static Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final cached = get<T>(key, ttl: ttl);
    if (cached != null) return cached;
    final fresh = await fetcher();
    set(key, fresh);
    return fresh;
  }

  /// Invalidiert einen einzelnen Eintrag. Aufrufen WANN IMMER Daten
  /// geschrieben werden (UPDATE/INSERT/DELETE).
  static void invalidate(String key) => _cache.remove(key);

  /// Invalidiert alle Einträge die mit prefix anfangen.
  /// Beispiel: invalidatePrefix('profile_') → leert alle profile_*-Caches.
  static void invalidatePrefix(String prefix) {
    _cache.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Komplett-Reset (bei Logout, Account-Wechsel).
  static void invalidateAll() => _cache.clear();

  /// Diagnostik: aktuelle Cache-Größe (nur für Debug-Anzeige).
  static int get size => _cache.length;
}
