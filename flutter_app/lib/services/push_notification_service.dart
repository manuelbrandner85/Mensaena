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

  /// FCM-Token holen + in Supabase `fcm_tokens` persistieren.
  /// Idempotent: existierender Eintrag wird per upsert ersetzt.
  /// Schreibt in `fcm_tokens` weil send-push Edge-Function von dort liest
  /// (NICHT push_subscriptions — das ist die Web-Push/VAPID-Tabelle).
  static Future<String?> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return null;
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return token;

      await sb.from('fcm_tokens').upsert(
        {
          'user_id': uid,
          'token': token,
          'active': true,
          'platform': 'android',
          'last_seen_at':
              DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
      return token;
    } catch (_) {
      return null;
    }
  }

  /// Token deaktivieren beim Logout — verhindert Push an alte Geraete.
  static Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      final uid = SupabaseService.currentUser?.id;
      if (token == null || uid == null) return;
      await sb
          .from('fcm_tokens')
          .update({'active': false})
          .eq('user_id', uid)
          .eq('token', token);
    } catch (_) {}
  }

  /// Token-Refresh-Stream → Re-Register beim Wechsel.
  static Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  /// Foreground Message-Stream — Phase 3 nutzt das fuer In-App-Toasts.
  static Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
}
