// OTA-Patch-Trigger: liefert die KI-Admin-Features (Risikoprofil, Trends,
// NL-Analytik) + Standort-Datenschutz + Livestream-Fix via Shorebird an
// bestehende Installationen aus (reparierter Patch-Workflow, PR #610).
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'providers/locale_provider.dart';
import 'providers/role_provider.dart';
import 'repositories/challenges_repository.dart';
import 'repositories/extra_repositories.dart';
import 'services/call_event_bus.dart';
import 'services/callkit_service.dart';
import 'services/device_tier_service.dart';
import 'services/incoming_call_overlay.dart';
import 'services/offline_queue_service.dart';
import 'services/push_notification_service.dart';
// Re-Export der Overlay-Entry-Point-Funktion (`@pragma('vm:entry-point')`),
// damit das Plugin sie beim Overlay-Start erreichen kann.
import 'widgets/overlays/incoming_call_overlay_app.dart'
    show incomingCallOverlayEntry;
import 'services/shorebird_patch_service.dart';
import 'services/sleep_reminder_service.dart';
import 'services/supabase_service.dart';
import 'repositories/wave_final_repositories.dart';

/// SKILL: mensaena-architektur
/// Bootstrap — Performance-optimiert:
///   1. KRITISCH (await): Supabase initialisieren (Session-Restore +
///      Anon-Key). Ohne das kann die App keine Daten holen.
///   2. Background-Handler MUSS vor runApp() registriert werden, sonst
///      gehen kalt-gestartete Pushes verloren (Firebase-Doku).
///   3. Alles andere (Firebase, FCM-Token, Auth-Listener) wird NICHT
///      awaitet — laeuft im Background nach erstem Frame. Das verhindert
///      "App baut sich nicht auf"-Verhalten wenn Firebase langsam ist.
/// Entry-Point für das Overlay-Isolate. flutter_overlay_window startet
/// dies, wenn der Main-Isolate `FlutterOverlayWindow.showOverlay()` ruft.
/// Der Name `overlayMain` ist vom Plugin fest vorgegeben.
@pragma('vm:entry-point')
void overlayMain() => incomingCallOverlayEntry();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRASH-FIX (App-langsam-/crasht-Report): Image-Cache eng deckeln.
  // Default-Flutter: 1000 Bilder / 100 MB. Auf Low-RAM-Android-Geräten
  // reicht ein einziges vom Server unsanft groß ausgeliefertes Avatar/
  // Cover-Bild aus, um den Decoder zu sprengen → Native-OOM-Crash.
  //
  // PERF-FIX 2: Tier-abhängige Caps (ARM32 / Android <9 = Lite-Mode):
  //   Lite     →  32 MB / 100 Bilder
  //   Standard →  64 MB / 200 Bilder
  // Detection läuft fire-and-forget; bis sie fertig ist, gilt der
  // großzügigere Standard-Cap.
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 * 1024 * 1024;
  unawaited(DeviceTierService.detect().then((info) {
    if (info.tier == DeviceTier.lite) {
      PaintingBinding.instance.imageCache.maximumSize = 100;
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          32 * 1024 * 1024;
    }
  }));

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
  // System-Overlay-Aktions-Listener: hört auf 'overlay_action' Messages aus
  // dem Overlay-Isolate (Annehmen/Ablehnen-Taps) und routet sie an
  // CallEventBus. MUSS vor runApp() laufen, damit Aktionen, die VOR dem
  // ersten Frame eintreffen (Cold-Start aus dem Overlay), nicht verloren gehen.
  IncomingCallOverlay.attachActionListener();

  // L18: Globaler Error-Boundary — verhindert Red-Screen-of-Death.
  // Statt Flutter's Default-Widget zeigen wir eine Cinema-Style Karte mit
  // freundlichem Text + Reload-Hinweis. In Release-Builds wird stack-trace
  // nicht angezeigt (Datenschutz).
  ErrorWidget.builder = (details) {
    const isDebug = !bool.fromEnvironment('dart.vm.product');
    return Material(
      color: const Color(0xFF0A0F1A),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2434).withValues(alpha: 0.9),
              border: Border.all(color: const Color(0xFFC79363).withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 36, color: Color(0xFFE26B6B)),
                const SizedBox(height: 12),
                const Text(
                  'Etwas ist schiefgelaufen',
                  style: TextStyle(
                    fontSize: 16, color: Color(0xFFE9E2D5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Diese Karte konnte nicht geladen werden. Tippe Zurück oder lade neu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFFB6AC9A), height: 1.4),
                ),
                if (isDebug) ...[
                  const SizedBox(height: 10),
                  Text(
                    details.exceptionAsString(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF8C8275)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  };

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

  // Tile-Cache fuer flutter_map initialisieren (Background, non-blocking).
  try {
    await FMTCObjectBoxBackend().initialise();
    await const FMTCStore('mensaena_tiles').manage.create();
  } catch (_) {/* FMTC nicht verfuegbar — Tiles werden ohne Cache geladen */}

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

  // FCM-Token + Role bei aktuellem Login direkt registrieren
  if (SupabaseService.isLoggedIn) {
    unawaited(PushNotificationService.registerToken());
    unawaited(UserRoleCache.reload());
    // Badge-Engine: verleiht beim Start retroaktiv alle erreichten Badges
    // (bisher gab es keine allgemeine Vergabe-Logik → Badges blieben leer).
    unawaited(ChallengesRepository.checkAndAwardBadges());
  }

  // Auth-State-Listener: bei Login/Logout Token + Rolle lifecycle managen
  sb.auth.onAuthStateChange.listen((event) {
    switch (event.event) {
      case AuthChangeEvent.signedIn:
        unawaited(PushNotificationService.registerToken());
        unawaited(UserRoleCache.reload());
        break;
      case AuthChangeEvent.signedOut:
        unawaited(PushNotificationService.unregisterToken());
        UserRoleCache.clear();
        break;
      default:
        break;
    }
  });

  // Token-Refresh-Stream: bei neuer Token-ID neu registrieren
  PushNotificationService.onTokenRefresh.listen((_) {
    unawaited(PushNotificationService.registerToken());
  });

  // Startup-Sound wird jetzt direkt im SplashScreen ausgelöst (zuverlässiges
  // Timing) — nicht mehr hier nach den Background-Init-awaits (kam zu spät).

  // Shorebird OTA-Patch: Check + Download im Background. Wenn ein neuer
  // Patch verfuegbar ist, laedt Shorebird ihn jetzt aktiv herunter
  // (vorher wurde nur checkForUpdate() aufgerufen → der Patch blieb auf
  // dem Server, der Client sah ihn nie). Nach erfolgreichem Download
  // feuert der Service ein onPatchReady-Event, die UpdateGate zeigt
  // dann den gruenen Restart-Banner.
  unawaited(ShorebirdPatchService.instance.checkAndDownloadPatch());

  // P12/P10/P11: drei Background-Tasks NIE sequenziell awaiten — sonst
  // blockt ein hängender Connectivity-Check oder tz-Init alle nachfolgenden
  // und kann beim Navigieren zu Stalls fuehren. Jede Task fire-and-forget
  // mit eigenem catchError damit eine Exception nicht den runZonedGuarded-
  // Wrapper aufwaermt.
  unawaited(
    OfflineQueueService.instance.install().catchError((_) {}),
  );
  unawaited(
    UserStreaksRepository().tickActivity().catchError((_) {}),
  );
  unawaited(
    SleepReminderService.instance.ensureScheduled().catchError((_) {}),
  );
}

/// Fire-and-forget helper.
void unawaited(Future<void> f) {
  f.catchError((_) {});
}
