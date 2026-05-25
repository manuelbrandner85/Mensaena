import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-architektur
/// Profile-Repository: Get/Update fuer profiles-Tabelle.
class ProfilesRepository {
  const ProfilesRepository._();

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
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime(2000),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
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
  static Future<void> update(String userId, Map<String, dynamic> patch) async {
    await sb.from('profiles').update(patch).eq('id', userId);
  }
}

/// Provider fuer das eigene Profil (vom aktuellen User).
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  // Re-trigger beim Auth-State-Wechsel.
  ref.watch(authStateProvider);
  return ProfilesRepository.getMine();
});
