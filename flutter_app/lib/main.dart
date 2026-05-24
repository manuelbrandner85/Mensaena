import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'providers/locale_provider.dart';
import 'services/push_notification_service.dart';
import 'services/supabase_service.dart';

/// SKILL: mensaena-architektur
/// Bootstrap — Performance-optimiert:
///   1. KRITISCH (await): Supabase initialisieren (Session-Restore +
///      Anon-Key). Ohne das kann die App keine Daten holen.
///   2. Background-Handler MUSS vor runApp() registriert werden, sonst
///      gehen kalt-gestartete Pushes verloren (Firebase-Doku).
///   3. Alles andere (Firebase, FCM-Token, Auth-Listener) wird NICHT
///      awaitet — laeuft im Background nach erstem Frame. Das verhindert
///      "App baut sich nicht auf"-Verhalten wenn Firebase langsam ist.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Supabase Session-Restore (kritisch, blockierend, ~100-300ms)
  await SupabaseService.init();

  // 1b. EasyLocalization — JSON-Translations vorladen.
  await EasyLocalization.ensureInitialized();

  // 2. Background-Handler-Registration (top-level @pragma function)
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

  // 3. App SOFORT rendern — kein await auf Firebase/FCM/Listener!
  runApp(
    EasyLocalization(
      supportedLocales: kSupportedLocales,
      path: 'assets/translations',
      fallbackLocale: kFallbackLocale,
      startLocale: kFallbackLocale,
      useOnlyLangCode: true,
      child: const ProviderScope(child: MensaenaApp()),
    ),
  );

  // 4. Nach erstem Frame: alles andere im Background initialisieren.
  // Wenn Firebase nicht konfiguriert ist (Dev-Build) faellt das
  // fail-silently. Push laeuft dann lokal nicht, App laeuft trotzdem.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initBackgroundServices();
  });
}

/// Alles was die UI nicht braucht laeuft hier im Background.
Future<void> _initBackgroundServices() async {
  try {
    await PushNotificationService.init();
  } catch (_) {}

  // FCM-Token bei aktuellem Login direkt registrieren
  if (SupabaseService.isLoggedIn) {
    unawaited(PushNotificationService.registerToken());
  }

  // Auth-State-Listener: bei Login/Logout Token-Lifecycle managen
  sb.auth.onAuthStateChange.listen((event) {
    switch (event.event) {
      case AuthChangeEvent.signedIn:
        unawaited(PushNotificationService.registerToken());
        break;
      case AuthChangeEvent.signedOut:
        unawaited(PushNotificationService.unregisterToken());
        break;
      default:
        break;
    }
  });

  // Token-Refresh-Stream: bei neuer Token-ID neu registrieren
  PushNotificationService.onTokenRefresh.listen((_) {
    unawaited(PushNotificationService.registerToken());
  });
}

/// Fire-and-forget helper.
void unawaited(Future<void> f) {
  f.catchError((_) {});
}
