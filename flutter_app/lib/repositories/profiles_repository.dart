import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-architektur
/// Profile-Repository: Get/Update fuer profiles-Tabelle.
class ProfilesRepository {
  const ProfilesRepository._();

  /// Leichtgewichtiger Name+Avatar-Lookup (z. B. Incoming-Call-UI).
  /// Bewusst KEIN Minimal-Fallback: null heisst "nicht aufloesbar".
  static Future<({String? displayName, String? avatarUrl})?> nameAndAvatar(
      String userId) async {
    try {
      final p = await sb
          .from('profiles')
          .select('display_name, name, avatar_url')
          .eq('id', userId)
          .maybeSingle();
      if (p == null) return null;
      return (
        displayName:
            (p['display_name'] as String?) ?? (p['name'] as String?),
        avatarUrl: p['avatar_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Profil per User-ID. NIEMALS null wenn userId vorhanden ist —
  /// fallback auf Minimal-Profile damit UI nie "Fehler beim Laden" zeigt.
  static Future<Profile?> getById(String userId) async {
    if (userId.isEmpty) {
      debugPrint('[ProfilesRepo] getById: empty userId');
      return null;
    }
    Map<String, dynamic>? row;
    try {
      row = await sb
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e, st) {
      debugPrint('[ProfilesRepo] getById($userId) query failed: $e');
      debugPrint('[ProfilesRepo] Stack: $st');
      // Selbst bei Query-Error: Minimal-Profile aus dem auth-User-Objekt.
      return _minimalFromAuth(userId);
    }
    if (row == null) {
      debugPrint('[ProfilesRepo] getById($userId): row null — fallback minimal');
      return _minimalFromAuth(userId);
    }
    try {
      return Profile.fromJson(row);
    } catch (e, st) {
      debugPrint('[ProfilesRepo] Profile.fromJson failed for $userId: $e');
      debugPrint('[ProfilesRepo] Stack: $st');
      debugPrint('[ProfilesRepo] Row keys: ${row.keys.toList()}');
      // Fallback aus geparsten DB-Feldern (so viel wie defensive moeglich).
      return _safeMinimal(row, userId);
    }
  }

  /// Minimal-Profile NUR aus der user-id (kein DB-Read).
  static Profile _minimalFromAuth(String userId) {
    return Profile(
      id: userId,
      createdAt: DateTime(2000),
      updatedAt: DateTime(2000),
      role: 'user',
      donorTier: 0,
      donationCount: 0,
      donationTotal: 0.0,
    );
  }

  /// Minimal-Profile aus DB-Row, alle optionalen Felder defensiv.
  static Profile _safeMinimal(Map<String, dynamic> row, String userId) {
    return Profile(
      id: userId,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toUtc() ??
          DateTime(2000),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '')?.toUtc() ??
          DateTime(2000),
      role: (row['role'] as String?) ?? 'user',
      donorTier: 0,
      donationCount: 0,
      donationTotal: 0.0,
      name: row['name'] as String?,
      displayName: row['display_name'] as String?,
      nickname: row['nickname'] as String?,
      email: row['email'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      bio: row['bio'] as String?,
      coverUrl: row['cover_url'] as String?,
      homeCity: row['home_city'] as String?,
      homePostalCode: row['home_postal_code'] as String?,
      country: row['country'] as String?,
    );
  }

  /// Profil des aktuell eingeloggten Users.
  static Future<Profile?> getMine() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      debugPrint('[ProfilesRepo] getMine: no currentUser');
      return null;
    }
    return getById(uid);
  }

  /// Profile patchen.
  /// L23: avatar_url + cover_url müssen aus dem Supabase-Storage stammen.
  /// Falls jemand versucht externe URLs einzukippen — werden sie ignoriert.
  /// Oeffentliche Profil-Statistiken (Posts/Gruppen/Challenges/Zeitbank).
  /// PERF: head-only counts statt Row-Listen (siehe Audit 2026-06);
  /// Timebank: hours+giver_id genuegt, status='confirmed' serverseitig.
  static Future<
      ({
        int posts,
        int groups,
        int activeChallenges,
        double hoursGiven,
        double hoursReceived
      })> publicStats(String userId) async {
    final results = await Future.wait<dynamic>([
      sb
          .from('posts')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'active')
          .count(CountOption.exact),
      sb
          .from('group_members')
          .select('id')
          .eq('user_id', userId)
          .count(CountOption.exact),
      sb
          .from('challenge_progress')
          .select('id')
          .eq('user_id', userId)
          .filter('completed_at', 'is', null)
          .neq('status', 'completed')
          .count(CountOption.exact),
      sb
          .from('timebank_entries')
          .select('hours, giver_id')
          .or('giver_id.eq.$userId,receiver_id.eq.$userId')
          .eq('status', 'confirmed'),
    ]);
    double given = 0;
    double received = 0;
    for (final r in (results[3] as List).whereType<Map<String, dynamic>>()) {
      final h = (r['hours'] as num?)?.toDouble() ?? 0;
      if (r['giver_id'] == userId) {
        given += h;
      } else {
        received += h;
      }
    }
    return (
      posts: (results[0] as PostgrestResponse).count,
      groups: (results[1] as PostgrestResponse).count,
      activeChallenges: (results[2] as PostgrestResponse).count,
      hoursGiven: given,
      hoursReceived: received,
    );
  }

  /// Liest die rohe dashboard_config (JSONB) eines Users (oder null).
  static Future<Map<String, dynamic>?> dashboardConfig(String userId) async {
    try {
      final row = await sb
          .from('profiles')
          .select('dashboard_config')
          .eq('id', userId)
          .maybeSingle();
      final raw = row?['dashboard_config'];
      return raw is Map ? Map<String, dynamic>.from(raw) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> update(String userId, Map<String, dynamic> patch) async {
    if (patch.containsKey('avatar_url')) {
      final v = patch['avatar_url'];
      if (v is String && v.isNotEmpty && !_isAllowedStorageUrl(v, 'avatars')) {
        patch.remove('avatar_url');
      }
    }
    if (patch.containsKey('cover_url')) {
      final v = patch['cover_url'];
      if (v is String && v.isNotEmpty && !_isAllowedStorageUrl(v, 'covers')) {
        patch.remove('cover_url');
      }
    }
    await sb.from('profiles').update(patch).eq('id', userId);
  }

  static final _storageHost = RegExp(
      r'^https://[a-z0-9-]+\.supabase\.co/storage/v1/object/public/');

  static bool _isAllowedStorageUrl(String url, String bucket) {
    final m = _storageHost.firstMatch(url);
    if (m == null) return false;
    return url.startsWith('${m.group(0)}$bucket/');
  }
}

/// Provider fuer das eigene Profil (vom aktuellen User).
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  // Re-trigger beim Auth-State-Wechsel.
  ref.watch(authStateProvider);
  return ProfilesRepository.getMine();
});
