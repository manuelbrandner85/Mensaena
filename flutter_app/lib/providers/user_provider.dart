import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase/database_service.dart';
import 'auth_provider.dart';

/// Profil-Daten des aktuell eingeloggten Users (profiles-Tabelle).
/// Wird automatisch neu geladen wenn currentUser sich aendert.
final currentProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return db.getProfile(user.id);
});

/// Profil-Daten eines beliebigen Users by id (fuer /profile/:id Seiten).
final profileByIdProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, id) {
  return db.getProfile(id);
});

/// Helper: Vollname des aktuellen Users (oder "Nachbar*in" als Fallback).
final currentDisplayNameProvider = Provider<String>((ref) {
  final profile = ref.watch(currentProfileProvider).asData?.value;
  return (profile?['full_name'] as String?)?.trim().isNotEmpty == true
      ? profile!['full_name'] as String
      : 'Nachbar*in';
});
