import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'providers/locale_provider.dart';
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
    // localeProvider mountet den Notifier — der ruft persistierten
    // Mode + ggf. GPS-Detect ab und triggert context.setLocale().
    ref.watch(localeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
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
