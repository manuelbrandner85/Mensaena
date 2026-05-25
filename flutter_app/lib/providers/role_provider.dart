/// SKILL: mensaena-architektur
/// Aktuelle User-Rolle (admin / moderator / user) — Cache + Provider.
///
/// Wird beim Login geladen und in einer statischen Variable gehalten,
/// damit `GoRouter.redirect` (sync callback) sie ohne async-Roundtrip
/// pruefen kann. Der `Provider` ist fuer UI-Watching.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

class UserRoleCache {
  const UserRoleCache._();

  static String? _role;

  static String? get role => _role;
  static bool get isAdmin => _role == 'admin';
  static bool get isModerator => _role == 'admin' || _role == 'moderator';

  /// Reload Role aus profiles.role. Wird beim Auth-Change in main.dart
  /// aufgerufen. Bei Logout: clear().
  static Future<void> reload() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      _role = null;
      return;
    }
    try {
      final row = await sb
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      _role = row?['role'] as String?;
    } catch (_) {
      _role = null;
    }
  }

  static void clear() {
    _role = null;
  }
}

/// Reactive Provider fuer Widgets die auf Role-Aenderung reagieren wollen.
/// Der eigentliche State sitzt in UserRoleCache (statisch), dieser Provider
/// triggert nur Rebuilds bei externen invalidate-Aufrufen.
final userRoleProvider = StateProvider<String?>((ref) {
  return UserRoleCache.role;
});
