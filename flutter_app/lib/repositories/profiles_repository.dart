import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-architektur
/// Profile-Repository: Get/Update fuer profiles-Tabelle.
class ProfilesRepository {
  const ProfilesRepository._();

  /// Profil per User-ID. null wenn nicht gefunden.
  static Future<Profile?> getById(String userId) async {
    try {
      final row =
          await sb.from('profiles').select().eq('id', userId).maybeSingle();
      if (row == null) return null;
      return Profile.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Profil des aktuell eingeloggten Users.
  static Future<Profile?> getMine() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
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
