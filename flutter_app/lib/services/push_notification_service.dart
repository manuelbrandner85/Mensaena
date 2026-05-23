import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'supabase_service.dart';

/// SKILL: mensaena-architektur
/// Firebase Cloud Messaging + Local-Notifications.
///
/// Architektur (production-grade):
///   1. main.dart ruft PushNotificationService.init() + bindet Background-
///      Handler via FirebaseMessaging.onBackgroundMessage(...).
///   2. Foreground-Messages → FcmForegroundListener-Widget zeigt Toast.
///   3. Background-Messages → _showLocalNotification baut native Android-
///      Notification mit korrektem channel_id ("mensaena_default"), Icon,
///      Sound, Vibration, click_action.
///   4. App-Closed: FCM weckt Android via High-Priority-Push (data-only fuer
///      incoming_call → 45s TTL), Android-System zeigt Notification ohne
///      dass die App laufen muss.
///   5. Token-Lifecycle: bei Login/Logout/Refresh registerToken() in
///      fcm_tokens.
class PushNotificationService {
  const PushNotificationService._();

  static const _channelId = 'mensaena_default';
  static const _channelName = 'Mensaena Benachrichtigungen';
  static const _channelDescription =
      'Nachrichten, Anrufe, Matches und Krisen-Warnungen';

  static final _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Bootstrap — Firebase init, Permissions, Channel-Setup, Listener.
  /// Wird in main.dart aufgerufen BEVOR runApp().
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();

      // Permission-Request (iOS + Android 13+)
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS: Foreground-Presentation aktivieren
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Local-Notifications-Plugin initialisieren
      const androidInit = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _localNotifications.initialize(
        const InitializationSettings(
          android: androidInit,
          iOS: iosInit,
        ),
      );

      // Android-Notification-Channel erstellen (Pflicht ab Android 8.0)
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Foreground-Listener — zeigt LOCAL Notification (falls keine UI sichtbar)
      // ZUSAETZLICH zum FcmForegroundListener-Widget (das Toasts zeigt).
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Notification-Tap-Handler — wenn User auf Notification klickt
      // waehrend App im Background ist.
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Wenn App durch Notification gestartet wurde (terminated → cold-start)
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _handleNotificationTap(initial);
    } catch (_) {
      // Firebase nicht konfiguriert (Dev-Build ohne google-services.json
      // → fail-silently). Production-Build hat google-services.json
      // via GitHub Actions Secret GOOGLE_SERVICES_JSON injected.
    }
  }

  /// Foreground-Handler — zeigt Local-Notification damit User immer
  /// einen visuellen Hinweis bekommt (auch bei nicht-sichtbaren Screens).
  /// Bevorzugt data.title/body weil FCM Android-Background diese Felder
  /// stabiler durchreicht als notification.title.
  static Future<void> _handleForegroundMessage(RemoteMessage m) async {
    final n = m.notification;
    final title = (m.data['title'] as String?) ?? n?.title;
    final body = (m.data['body'] as String?) ?? n?.body;
    if (title == null && body == null) return;
    await _showLocalNotification(
      id: m.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title ?? 'Mensaena',
      body: body ?? '',
      payload: m.data['url'] as String? ?? m.data['link'] as String?,
    );
  }

  /// Tap-Handler — wenn User Notification klickt (App war im Background
  /// oder terminated). Hier kann Deep-Link-Navigation erfolgen, aktuell
  /// uebernimmt der FcmForegroundListener das im Foreground; im
  /// Background-Tap landet der User per FlutterEngine-Restart auf der
  /// Initial-Route, GlobalRouter-Redirect macht den Rest.
  static void _handleNotificationTap(RemoteMessage m) {
    // Aktuell stille — App-Restart navigiert via initialMessage zur URL
    // ueber Deep-Link-Plugin (Phase 4).
  }

  /// Native Local-Notification anzeigen (Android: System-Tray + Sound).
  static Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );
  }

  /// FCM-Token holen + in Supabase `fcm_tokens` persistieren.
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
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
      return token;
    } catch (_) {
      return null;
    }
  }

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

  static Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  static Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
}

/// SKILL: mensaena-architektur
/// Background-Message-Handler — laeuft in separater Isolate wenn App
/// im Background ist oder terminated. Muss top-level + @pragma annotated
/// sein damit Flutter-Engine-Restart sie korrekt aufrufen kann.
///
/// Wird in main.dart via FirebaseMessaging.onBackgroundMessage() registriert.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage m) async {
  // Wenn das Edge-Function FCM-Payload `notification` UND `data` schickt,
  // zeigt Android automatisch die Notification. Bei data-only Pushes
  // (z.B. incoming_call mit TTL=45s) muessen WIR die Notification bauen.
  try {
    await Firebase.initializeApp();
    final n = m.notification;
    // data.* hat Vorrang — Android-Background haengt notification.title oft ab.
    final title = (m.data['title'] as String?) ?? n?.title;
    final body = (m.data['body'] as String?) ?? n?.body;
    if (title == null && body == null) return;

    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
        const InitializationSettings(android: androidInit));

    const androidChannel = AndroidNotificationChannel(
      'mensaena_default',
      'Mensaena Benachrichtigungen',
      description: 'Nachrichten, Anrufe, Matches und Krisen-Warnungen',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const androidDetails = AndroidNotificationDetails(
      'mensaena_default',
      'Mensaena Benachrichtigungen',
      channelDescription:
          'Nachrichten, Anrufe, Matches und Krisen-Warnungen',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    await plugin.show(
      m.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title ?? 'Mensaena',
      body ?? '',
      const NotificationDetails(android: androidDetails),
      payload: m.data['url'] as String?,
    );
  } catch (_) {
    // ignore — App ist im Background, nichts was wir interaktiv tun koennten
  }
}
