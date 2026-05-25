import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-architektur
/// Profile-Repository: Get/Update fuer profiles-Tabelle.
class ProfilesRepository {
  const ProfilesRepository._();

  /// Profil per User-ID. null wenn nicht gefunden ODER bei Fehler.
  /// Fehler werden via debugPrint geloggt damit wir Diagnose haben.
  static Future<Profile?> getById(String userId) async {
    try {
      final row =
          await sb.from('profiles').select().eq('id', userId).maybeSingle();
      if (row == null) {
        debugPrint('[ProfilesRepo] getById($userId): row is null');
        return null;
      }
      try {
        return Profile.fromJson(row);
      } catch (e, st) {
        // Parse-Fehler explizit loggen — frueher silent-null, jetzt mit
        // Detail (welches Feld?). Wir geben trotzdem ein default-Profile
        // zurueck damit die UI was zum Anzeigen hat.
        debugPrint('[ProfilesRepo] Profile.fromJson failed for $userId: $e');
        debugPrint('[ProfilesRepo] Stack: $st');
        debugPrint('[ProfilesRepo] Row keys: ${row.keys.toList()}');
        // Fallback: minimal-Profile mit nur id damit UI nicht crashed.
        return Profile(
          id: userId,
          createdAt: DateTime(2000),
          updatedAt: DateTime(2000),
          role: (row['role'] as String?) ?? 'user',
          donorTier: 0,
          donationCount: 0,
          donationTotal: 0.0,
          name: row['name'] as String?,
          displayName: row['display_name'] as String?,
          email: row['email'] as String?,
          avatarUrl: row['avatar_url'] as String?,
          bio: row['bio'] as String?,
        );
      }
    } catch (e, st) {
      debugPrint('[ProfilesRepo] getById($userId) outer error: $e');
      debugPrint('[ProfilesRepo] Stack: $st');
      return null;
    }
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
