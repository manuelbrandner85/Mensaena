import 'package:easy_localization/easy_localization.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'providers/accessibility_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'repositories/extra_repositories.dart';
import 'repositories/notification_prefs_repository.dart';
import 'services/deep_link_service.dart';
import 'services/memory_watchdog_service.dart';
import 'services/push_notification_service.dart';
import 'services/supabase_service.dart';
import 'widgets/shared/biometric_lock_gate.dart';
import 'widgets/shared/critical_crisis_alert_listener.dart';
import 'widgets/shared/fcm_foreground_listener.dart';
import 'widgets/shared/incoming_call_listener.dart';
import 'widgets/shared/connectivity_banner.dart';
import 'widgets/shared/notification_permission_banner.dart';
import 'widgets/shared/permissions_gate_guard.dart';
import 'widgets/shared/update_gate.dart';

/// SKILL: mensaena-architektur
/// Root-Widget. MaterialApp.router mit GoRouter aus app_router.dart.
///
/// ZUSATZ-3 PiP: WidgetsBindingObserver lauscht auf AppLifecycleState.paused.
/// Wenn die App minimiert wird UND ein DM-Call oder Group-Call läuft,
/// triggern wir automatisch PiP — Audio/Video bleiben damit aktiv im
/// System-PiP-Fenster statt zu pausieren.
class MensaenaApp extends ConsumerStatefulWidget {
  const MensaenaApp({super.key});

  @override
  ConsumerState<MensaenaApp> createState() => _MensaenaAppState();
}

class _MensaenaAppState extends ConsumerState<MensaenaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Globaler Speicher-Wächter: einmalige Initialisierung. Räumt den
    // Image-Cache proaktiv, bevor er das harte Limit reißt (→ kein OOM-Crash
    // / kein Langsamer-Werden über Stunden). Siehe MemoryWatchdogService.
    MemoryWatchdogService.instance.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MemoryWatchdogService.instance.stop();
    super.dispose();
  }

  @override
  void didHaveMemoryPressure() {
    // Android meldet akuten RAM-Mangel → kompletter Cache-Reset, bevor das
    // System uns hart killt.
    MemoryWatchdogService.instance.onMemoryPressure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User-Wunsch (2026-05): KEIN Auto-PiP bei App-Minimize.
    // Der User will sich innerhalb der App frei bewegen während Call/
    // Livestream läuft. Das übernimmt der ActiveCallMiniPlayer im
    // DashboardScaffold — er bleibt sichtbar sobald activeCallProvider
    // gesetzt ist + der User vom Call-Screen weg navigiert.
    // System-PiP-Mode wird hier NICHT mehr automatisch getriggert.
    //
    // MEMORY: Beim Minimieren die "lebenden" (nicht sichtbaren) Bilder
    // freigeben — andere Apps bekommen den RAM, beim Zurückkehren werden
    // sie bei Bedarf neu decodiert.
    if (state == AppLifecycleState.paused) {
      MemoryWatchdogService.instance.onAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isLight = ref.watch(isLightModeProvider);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor:
            isLight ? const Color(0xFFF5F5F0) : const Color(0xFF0A0F1C),
        systemNavigationBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
      ),
    );

    final router = ref.watch(goRouterProvider);
    // F23: globalen Router-Ref für Push-Tap-Routing setzen.
    PushNotificationService.rootRouter = router;
    // Deep-Links: einmalig App-Links-Stream koppeln (https://mensaena.de/...
    // → GoRouter). initialize() ist idempotent.
    DeepLinkService.instance.initialize(router: router);
    // N1 Quiet-Hours: Prefs einmal warm laden, damit der FCM-Foreground-
    // Listener den Cache synchron prüfen kann (kein async im Hot-Path).
    ref.watch(myNotifPrefsProvider);
    // localeProvider mountet den Notifier — der ruft persistierten
    // Mode + ggf. GPS-Detect ab und triggert context.setLocale().
    ref.watch(localeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      // UpdateGate + IncomingCallListener wrappen alle Screens.
      // BetterFeedback umrahmt zusätzlich für Shake-to-Report (Sprint 5).
      builder: (context, navChild) {
        // F20 a11y: globale TextScale-Override aus User-Pref.
        final a11y = ref.watch(a11yProvider);
        final media = MediaQuery.of(context);
        final scaled = media.copyWith(
          textScaler: TextScaler.linear(a11y.textScale),
        );
        return MediaQuery(
          data: scaled,
          child: BetterFeedback(
        themeMode: themeMode,
        darkTheme: FeedbackThemeData.dark(),
        child: UpdateGate(
          child: BiometricLockGate(
            child: IncomingCallListener(
              child: FcmForegroundListener(
              child: CriticalCrisisAlertListener(
              child: _ShakeFeedbackListener(
                child: Stack(
                  children: [
                    // PermissionsGateGuard prüft post-login + bei jedem
                    // App-Start, ob der Vollbild-Gate angezeigt werden muss
                    // (mind. eine Berechtigung offen UND noch nicht 3 ×
                    // versucht). Falls ja: pusht /gate (PopScope canPop:false).
                    // Falls alle erteilt oder erschöpft: ggf. ein einmaliger
                    // Hinweis-Snackbar pro Session. Ersetzt die früheren
                    // BatteryOptimizationPrompt + PermissionsBootstrap
                    // Auto-Dialoge — beide Funktionen leben jetzt im Gate.
                    PermissionsGateGuard(
                      child: navChild ?? const SizedBox.shrink(),
                    ),
                    // Globaler Push-Permission-Soft-Prompt — slidet 5s nach
                    // Start ein, falls Status notDetermined/denied ist.
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: NotificationPermissionBanner(),
                    ),
                    // H6: Globaler Offline-Banner — zeigt app-weit, wenn keine
                    // Internetverbindung besteht (statt stiller Fehler).
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ConnectivityBanner(),
                    ),
                  ],
                ),
              ),
              ),
              ),
            ),
          ),
        ),
          ),
        );
      },
    );
  }
}

/// Globaler "Schüttel-zum-Melden"-Listener. Bei Shake → BetterFeedback
/// Sheet mit Screenshot-Markup. Submit → error_logs.
class _ShakeFeedbackListener extends StatelessWidget {
  const _ShakeFeedbackListener({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Long-press 3-Finger als manueller Trigger (Shake-Detection erfordert
      // sensors_plus, also bieten wir 3-Finger-Long-Press als simple Alternative).
      onLongPress: () => BetterFeedback.of(context).show((feedback) async {
        await ErrorLogsRepository.log(
          errorType: 'user_feedback',
          message: feedback.text,
          stack: feedback.extra?.toString(),
          deviceInfo:
              'screenshot=${feedback.screenshot.length} bytes; user=${SupabaseService.currentUser?.id ?? "anon"}',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('common.feedbackThanks'.tr()),
          ));
        }
      }),
      child: child,
    );
  }
}
