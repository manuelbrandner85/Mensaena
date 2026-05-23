import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'services/push_notification_service.dart';
import 'services/supabase_service.dart';

/// SKILL: mensaena-architektur
/// Bootstrap-Sequenz:
///   1. Supabase initialisieren (Session aus Secure-Storage restoren)
///   2. Firebase / FCM initialisieren (Token + Permission Prompt)
///   3. Bei Login automatisch FCM-Token in fcm_tokens registrieren
///   4. Bei Logout Token deaktivieren
///   5. MaterialApp.router starten
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  // Firebase async — kann ggf. fail-silently bei fehlender Konfiguration
  // (Dev-Builds ohne google-services.json). Push laeuft dann lokal nicht,
  // Production-Build mit Secret hat das google-services.json.
  await PushNotificationService.init();
  // Wenn bereits eingeloggt → Token sofort registrieren
  if (SupabaseService.isLoggedIn) {
    PushNotificationService.registerToken();
  }
  // Bei jedem Login/Logout: Token-Lifecycle managen
  sb.auth.onAuthStateChange.listen((event) {
    switch (event.event) {
      case AuthChangeEvent.signedIn:
        PushNotificationService.registerToken();
        break;
      case AuthChangeEvent.signedOut:
        PushNotificationService.unregisterToken();
        break;
      default:
        break;
    }
  });
  // Token-Refresh-Stream: bei neuer Token-ID neu registrieren
  PushNotificationService.onTokenRefresh.listen((_) {
    PushNotificationService.registerToken();
  });
  runApp(const ProviderScope(child: MensaenaApp()));
}
