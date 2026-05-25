import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'providers/locale_provider.dart';
import 'repositories/extra_repositories.dart';
import 'services/call_event_bus.dart';
import 'services/callkit_service.dart';
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

  // Globaler Crash-Reporter → error_logs Tabelle in Supabase.
  // Per fail-silent: ErrorLogsRepository fängt eigene Exceptions ab.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorLogsRepository.log(
      errorType: 'FlutterError',
      message: details.exceptionAsString(),
      stack: details.stack?.toString(),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLogsRepository.log(
      errorType: 'Uncaught',
      message: error.toString(),
      stack: stack.toString(),
    );
    // Critical: return true so Flutter marks the error as handled and the
    // Engine does NOT eskaliert to native crash. Returning false caused
    // RealtimeSubscribeException + sensors_plus "No active stream"
    // exceptions to kill the whole App during screen-transitions.
    return true;
  };

  // 1. Supabase Session-Restore (kritisch, blockierend, ~100-300ms)
  await SupabaseService.init();

  // 1b. EasyLocalization — JSON-Translations vorladen.
  await EasyLocalization.ensureInitialized();

  // 2. Background-Handler-Registration (top-level @pragma function)
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

  // 2b. CallEventBus VOR runApp — kritisch fuer Cold-Start. Ein Accept-
  // Event aus killed-State feuert bevor irgendein Widget mountet, also
  // muss der Listener jetzt schon hoeren. Sonst Accept → Dashboard statt
  // Call-Screen.
  CallEventBus.init();

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

  // Native Call-UI (flutter_callkit_incoming): WhatsApp-Style Ringing.
  try {
    await CallkitService.initialize();
  } catch (_) {}

  // Android 14+: Full-Screen-Intent fuer eingehende Calls braucht
  // Runtime-Permission. Ohne das zeigt das System nur eine Heads-Up-
  // Notification statt der Lockscreen-Vollbild-UI.
  try {
    final canUse = await FlutterCallkitIncoming.canUseFullScreenIntent();
    if (canUse != true) {
      await FlutterCallkitIncoming.requestFullIntentPermission();
    }
  } catch (_) {/* nicht auf allen Android-Versionen verfuegbar */}

  // Cold-Start-Recovery: wenn die App via CallKit-Accept aus killed-State
  // gestartet wurde, hat _handle() ggf. das Event verpasst (vor Engine-
  // Boot gefeuert). Wir queryen activeCalls und triggern Accept manuell.
  unawaited(CallEventBus.recoverColdStart());

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
