import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/accessibility_store.dart';
import 'core/crash_log.dart';
import 'core/i18n.dart';
import 'core/supabase.dart';
import 'features/updates/update_gate.dart';
import 'routing/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

/// Entry-Point der Mensaena-Flutter-App.
///
/// runZonedGuarded fängt alle uncaught Errors aus dem Async-Stack ab –
/// damit die App im Release-Mode nicht stumm crasht (siehe „Fehler bei
/// mensaena aufgetreten"-Dialog), sondern einen lesbaren Error-Screen
/// anzeigt. FlutterError.onError leitet zudem alle Widget-Tree-Fehler
/// in dieselbe Senke um.
void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: AppColors.background,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.paper,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
        unawaited(CrashLog.capture(
          errorType: 'flutter_error',
          error: details.exception,
          stack: details.stack,
          extraContext: details.library,
        ),);
      };

      // Locale-Init darf nicht crashen
      try {
        await initializeDateFormatting('de_DE');
      } catch (e, st) {
        debugPrint('initializeDateFormatting failed: $e\n$st');
      }

      Object? bootError;
      StackTrace? bootStack;
      try {
        await initSupabase();
      } catch (e, st) {
        bootError = e;
        bootStack = st;
        debugPrint('initSupabase failed: $e\n$st');
      }

      // Nach erfolgreichem Supabase-Init: queued Crash-Reports flushen.
      if (bootError == null) {
        unawaited(CrashLog.flushPending());
      }

      runApp(
        ProviderScope(
          child: bootError != null
              ? _BootError(error: bootError, stack: bootStack)
              : const MensaenaApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Uncaught zone error: $error\n$stack');
      unawaited(CrashLog.capture(
        errorType: 'zone_error',
        error: error,
        stack: stack,
      ),);
    },
  );
}

class MensaenaApp extends ConsumerWidget {
  const MensaenaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return UpdateGate(child: _RouterApp());
  }
}

class _RouterApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final a11y = ref.watch(accessibilityProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Mensaena',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: a11y.themeMode,
      builder: (context, child) {
        // Wendet die User-Schriftgrößen-Skalierung global an, ohne die
        // System-Skalierung komplett zu ignorieren — Multiplikation.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: a11y.textScale,
              maxScaleFactor: a11y.textScale,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
      locale: locale,
      supportedLocales: const [
        Locale('de'),
        Locale('en'),
        Locale('it'),
        Locale('tr'),
        Locale('uk'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Fallback-UI, falls die App-Initialisierung wirft. Zeigt die
/// Fehlermeldung statt stillem Absturz.
class _BootError extends StatelessWidget {
  const _BootError({required this.error, this.stack});
  final Object error;
  final StackTrace? stack;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mensaena',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xFFB91C1C),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mensaena konnte nicht starten',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Beim Initialisieren ist ein Fehler aufgetreten. '
                  'Bitte starte die App neu oder kontaktiere den Support.',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    '$error',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
                if (stack != null && kDebugMode) ...[
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        '$stack',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
