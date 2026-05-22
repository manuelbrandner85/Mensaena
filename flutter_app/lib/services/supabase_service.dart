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
