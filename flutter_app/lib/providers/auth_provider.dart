import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase/auth_service.dart';
import '../services/supabase/supabase_service.dart';

/// Stream des aktuellen AuthState. Aenderungen (login, logout, refresh)
/// werden in Echtzeit propagiert.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return authService.authStateChanges;
});

/// Aktueller User oder null. Reagiert auf authStateChanges.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateChangesProvider).asData?.value;
  return state?.session?.user ?? supabase.currentUser;
});

/// Liefert true wenn ein User eingeloggt ist (bequem fuer AuthGuard).
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});
