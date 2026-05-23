import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'supabase_service.dart';

/// SKILL: mensaena-architektur
/// Firebase Cloud Messaging Initialisierung + Token-Registrierung in
/// push_subscriptions. Phase-1-Skeleton, Foreground-Handler kommt in
/// Phase 3 (notifications-screen).
class PushNotificationService {
  const PushNotificationService._();

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Firebase nicht konfiguriert (Dev-Build ohne google-services.json
      // → fail-silently).
    }
  }

  /// FCM-Token holen + in Supabase push_subscriptions persistieren.
  /// Idempotent: existierende Subscription wird per upsert ersetzt.
  static Future<String?> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return null;
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return token;

      await sb.from('push_subscriptions').upsert(
        {
          'user_id': uid,
          'endpoint': token,
          'p256dh': '',
          'auth': '',
          'active': true,
          'device_type': 'android',
        },
        onConflict: 'user_id,endpoint',
      );
      return token;
    } catch (_) {
      return null;
    }
  }

  /// Token-Refresh-Stream → Re-Register beim Wechsel.
  static Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  /// Foreground Message-Stream — Phase 3 nutzt das fuer In-App-Toasts.
  static Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
}
