import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Initialisiert Supabase mit denselben Credentials wie die Web-App.
/// Sessions werden lokal über flutter_secure_storage gespeichert.
Future<void> initSupabase() async {
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

/// Globaler Zugriff auf den Supabase-Client (Singleton).
SupabaseClient get sb => Supabase.instance.client;

/// Riverpod-Provider für den Supabase-Client.
final supabaseProvider = Provider<SupabaseClient>((ref) => sb);

/// Aktueller Auth-Status als Stream (Pendant zu onAuthStateChange im Web).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return sb.auth.onAuthStateChange;
});

/// Aktueller User (oder null).
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider).asData?.value;
  return state?.session?.user ?? sb.auth.currentUser;
});
