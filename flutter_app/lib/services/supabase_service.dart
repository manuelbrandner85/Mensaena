import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// SKILL: supabase
/// Initialisierung + Singleton-Zugriff auf Supabase. Gleiches Projekt wie
/// www.mensaena.de (gyqujitkvymlmgroovch).
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

/// True, wenn der Fehler ein transienter Netzwerk-/Token-Refresh-Fehler ist
/// und KEIN App-Bug. `AuthRetryableFetchException` (gotrue) und
/// `SocketException` (dart:io) treten bei flakigem Netz oder beim
/// Background-Token-Refresh auf — sie dürfen die App NICHT crashen lassen.
bool isTransientAuthNetworkError(Object error) =>
    error is AuthRetryableFetchException || error is SocketException;

/// Standard-`onError` für alle `sb.auth.onAuthStateChange.listen(...)`-Abos.
/// Verschluckt transiente Netzwerk-/Auth-Fehler still (kein Rethrow), damit
/// ein kurzer Verbindungsausfall keinen Fatal-Crash auslöst. Im Debug-Build
/// wird die Ursache geloggt; unerwartete Fehler werden ebenfalls geloggt,
/// aber nicht eskaliert.
void handleAuthStreamError(Object error, [StackTrace? stack]) {
  if (isTransientAuthNetworkError(error)) {
    if (kDebugMode) {
      debugPrint('[auth] transienter Netzwerkfehler ignoriert: $error');
    }
    return;
  }
  if (kDebugMode) {
    debugPrint('[auth] unerwarteter Auth-Stream-Fehler: $error');
  }
}

/// Riverpod Auth-State-Stream. Transiente Netzwerk-/Refresh-Fehler werden
/// still verschluckt, damit der Provider sie nicht als `AsyncError` an die
/// UI durchreicht (sonst Red-Screen bei kurzem Verbindungsverlust).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return sb.auth.onAuthStateChange.handleError(
    (Object error, StackTrace _) => handleAuthStreamError(error),
    test: (Object? error) =>
        error != null && isTransientAuthNetworkError(error),
  );
});

/// Aktueller User aus Auth-State.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider).asData?.value;
  return state?.session?.user ?? sb.auth.currentUser;
});
