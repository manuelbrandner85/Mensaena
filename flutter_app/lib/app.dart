import 'package:easy_localization/easy_localization.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'config/routes/app_router.dart';
import 'config/theme/app_theme.dart';
import 'providers/locale_provider.dart';
import 'repositories/extra_repositories.dart';
import 'services/supabase_service.dart';
import 'widgets/shared/incoming_call_listener.dart';
import 'widgets/shared/notification_permission_banner.dart';
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
      // UpdateGate + IncomingCallListener wrappen alle Screens.
      // BetterFeedback umrahmt zusätzlich für Shake-to-Report (Sprint 5).
      builder: (context, navChild) => BetterFeedback(
        themeMode: ThemeMode.dark,
        darkTheme: FeedbackThemeData.dark(),
        child: UpdateGate(
          child: IncomingCallListener(
            child: _ShakeFeedbackListener(
              child: Stack(
                children: [
                  navChild ?? const SizedBox.shrink(),
                  // Globaler Push-Permission-Soft-Prompt — slidet 5s nach
                  // Start ein, falls Status notDetermined/denied ist.
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: NotificationPermissionBanner(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
