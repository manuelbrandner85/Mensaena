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

import 'dart:async';
import 'dart:collection';

class _CacheEntry {
  _CacheEntry(this.data, this.timestamp, this.ttl);
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

class QueryCache {
  QueryCache._();

  /// Maximale Anzahl gecachter Einträge (LRU-Eviction danach).
  static const int _kMaxEntries = 200;

  /// Intervall des periodischen Sweeps für abgelaufene Einträge.
  static const Duration _kSweepInterval = Duration(minutes: 5);

  // LinkedHashMap preserves insertion order → ermöglicht LRU (ältester = erster Key).
  static final LinkedHashMap<String, _CacheEntry> _cache =
      LinkedHashMap<String, _CacheEntry>();

  static Timer? _sweepTimer;

  static void _ensureSweepTimer() {
    _sweepTimer ??= Timer.periodic(_kSweepInterval, (_) => sweepExpired());
  }

  /// Liefert gecached'tes Item zurück oder null wenn TTL abgelaufen / nicht vorhanden.
  /// Bei einem Cache-Hit wird der Eintrag als "zuletzt genutzt" markiert (LRU).
  static T? get<T>(String key, {Duration ttl = const Duration(minutes: 5)}) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > ttl) {
      _cache.remove(key);
      return null;
    }
    // LRU: Eintrag ans Ende bewegen (most-recently-used).
    _cache.remove(key);
    _cache[key] = entry;
    return entry.data as T?;
  }

  /// Schreibt einen neuen Cache-Eintrag (TS = jetzt).
  /// Erzwingt LRU-Cap: ältester Eintrag wird verworfen, wenn das Limit erreicht ist.
  static void set(String key, dynamic data,
      {Duration ttl = const Duration(minutes: 5)}) {
    _ensureSweepTimer();
    // Bestehenden Eintrag entfernen, damit die neue Insertion am Ende landet.
    _cache.remove(key);
    // LRU-Eviction: ältesten Eintrag (erstes Element) entfernen.
    if (_cache.length >= _kMaxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CacheEntry(data, DateTime.now(), ttl);
  }

  /// Entfernt alle Einträge, deren TTL abgelaufen ist.
  /// Wird periodisch durch den internen Sweep-Timer aufgerufen; kann auch
  /// manuell ausgelöst werden (z. B. durch den MemoryWatchdog).
  static void sweepExpired() {
    _cache.removeWhere((_, entry) => entry.isExpired);
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
    set(key, fresh, ttl: ttl);
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

  /// Komplett-Reset (bei Logout, Account-Wechsel, Speicherdruck).
  static void invalidateAll() => _cache.clear();

  /// Diagnostik: aktuelle Cache-Größe (nur für Debug-Anzeige).
  static int get size => _cache.length;
}
