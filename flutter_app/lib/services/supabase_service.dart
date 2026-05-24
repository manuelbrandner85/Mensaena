import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// SKILL: supabase
/// Initialisierung + Singleton-Zugriff auf Supabase. Gleiches Projekt wie
/// www.mensaena.de (huaqldjkgyosefzfhjnf).
class SupabaseService {
  const SupabaseService._();

  static Future<void> init() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.warn,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;
  static bool get isLoggedIn => currentSession != null;

  /// Stellt sicher, dass die Session frisch ist. Wenn das Token in den
  /// nächsten 60 s abläuft (oder schon abgelaufen ist), wird ein
  /// refreshSession() ausgelöst. Bei Background-Phasen pausiert
  /// supabase_flutter den Auto-Refresh — vor kritischen Inserts
  /// (DM-Call, Livestream, Post) sollte dieser Helper aufgerufen werden,
  /// sonst werden RLS-Inserts mit "JWT expired" abgewiesen.
  static Future<bool> ensureFreshSession() async {
    final s = currentSession;
    if (s == null) return false;
    final expiresAt = s.expiresAt;
    if (expiresAt == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiresAt - now > 60) return true;
    try {
      final res = await client.auth.refreshSession();
      return res.session != null;
    } catch (_) {
      return currentSession != null;
    }
  }
}

/// Kurzform — global verwendet.
SupabaseClient get sb => SupabaseService.client;

/// Riverpod Auth-State-Stream.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return sb.auth.onAuthStateChange;
});

/// Aktueller User aus Auth-State.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider).asData?.value;
  return state?.session?.user ?? sb.auth.currentUser;
});
