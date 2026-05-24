import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'widgets/shared/incoming_call_listener.dart';
import 'widgets/shared/update_gate.dart';

/// SKILL: mensaena-architektur
/// Root-Widget. MaterialApp.router mit GoRouter aus app_router.dart.
class MensaenaApp extends ConsumerWidget {
  const MensaenaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0F1C),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
      locale: const Locale('de', 'DE'),
      // UpdateGate wickelt jede Seite — bei mandatory Update wird ALLES
      // blockiert bis APK heruntergeladen ist.
      // IncomingCallListener wickelt das Navigator-Child damit eingehende
      // DM-Calls als Fullscreen-Dialog ueberall sichtbar werden.
      builder: (context, navChild) => UpdateGate(
        child: IncomingCallListener(
          child: navChild ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
