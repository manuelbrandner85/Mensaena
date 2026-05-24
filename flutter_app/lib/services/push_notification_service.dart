import 'dart:async';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
  // Channel-Beschreibungen werden zur Laufzeit übersetzt
  // (siehe init()), Default als Fallback wenn .tr() noch nicht verfügbar.
  static const _channelDescriptionFallback =
      'Nachrichten, Matches und allgemeine Benachrichtigungen';

  // Separate high-priority channel for incoming calls — fullScreenIntent +
  // long vibration pattern, Importance.max so it always rings through.
  static const _callsChannelId = 'mensaena_calls';
  static const _callsChannelName = 'Eingehende Anrufe';
  static const _callsChannelDescriptionFallback =
      'Hochprioritaere Push fuer eingehende DM-Anrufe';

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

      // 6 Android-Notification-Channels nach Kategorie (Weltenbibliothek-Stil):
      //   _default — Fallback (HIGH)
      //   _calls   — Anruf-Notifications (MAX + fullscreen-fähig)
      //   _crisis  — Krisen / Notfall (MAX + lange Vibration)
      //   _chat    — DM/Channel-Nachrichten (HIGH + Sound)
      //   _social  — Reaktionen/Kommentare/Events/Marketplace (DEFAULT)
      //   _system  — Badges/Updates/Achievements (LOW + ohne Sound)
      // Beschreibungen via tr() — Fallback wenn EasyLocalization noch nicht
      // bereit ist (z.B. in Background-Isolate).
      String trOr(String key, String fallback) {
        try {
          final translated = tr(key);
          // tr() returns the key if not found
          return translated == key ? fallback : translated;
        } catch (_) {
          return fallback;
        }
      }
      final androidChannel = AndroidNotificationChannel(
        _channelId, _channelName,
        description: trOr('push.channels.fallbackDesc', _channelDescriptionFallback),
        importance: Importance.high, playSound: true, enableVibration: true,
      );
      final callsChannel = AndroidNotificationChannel(
        _callsChannelId, _callsChannelName,
        description: trOr('push.channels.callsDesc', _callsChannelDescriptionFallback),
        importance: Importance.max, playSound: true, enableVibration: true,
        vibrationPattern:
            Int64List.fromList(<int>[0, 1000, 500, 1000, 500, 1000]),
      );
      final crisisChannel = AndroidNotificationChannel(
        'mensaena_crisis', 'Notfälle & Krisen',
        description: trOr('push.channels.crisisDesc', 'Krisen-Warnungen in deiner Nähe'),
        importance: Importance.max, playSound: true, enableVibration: true,
        vibrationPattern:
            Int64List.fromList(<int>[0, 800, 200, 800, 200, 800]),
      );
      final chatChannel = AndroidNotificationChannel(
        'mensaena_chat', 'Nachrichten',
        description: trOr('push.channels.messagesDesc', 'Direkt- und Community-Nachrichten'),
        importance: Importance.high, playSound: true, enableVibration: true,
      );
      final socialChannel = AndroidNotificationChannel(
        'mensaena_social', 'Community-Aktivität',
        description: trOr('push.channels.activityDesc', 'Reaktionen, Kommentare, Events, Marktplatz'),
        importance: Importance.defaultImportance,
        playSound: true, enableVibration: true,
      );
      final systemChannel = AndroidNotificationChannel(
        'mensaena_system', 'System & Achievements',
        description: trOr('push.channels.generalDesc', 'Badges, Updates und Hinweise'),
        importance: Importance.low, playSound: false, enableVibration: false,
      );
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(androidChannel);
      await androidPlugin?.createNotificationChannel(callsChannel);
      await androidPlugin?.createNotificationChannel(crisisChannel);
      await androidPlugin?.createNotificationChannel(chatChannel);
      await androidPlugin?.createNotificationChannel(socialChannel);
      await androidPlugin?.createNotificationChannel(systemChannel);

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
    final category = m.data['category'] as String? ?? 'social';
    final priority = m.data['priority'] as String? ?? 'normal';
    final type = m.data['type'] as String?;
    await _showLocalNotification(
      id: m.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title ?? 'Mensaena',
      body: body ?? '',
      payload: m.data['url'] as String? ?? m.data['link'] as String?,
      channelId: _channelForCategory(category, priority, type),
    );
  }

  /// Mapped category+priority+type auf eine der 6 Notification-Channels.
  /// Spiegel der channelFor()-Logik in send-push v22.
  static String _channelForCategory(
      String category, String priority, String? type) {
    if (type == 'incoming_call') return 'mensaena_calls';
    if (category == 'crisis' || priority == 'high') return 'mensaena_crisis';
    if (category == 'chat') return 'mensaena_chat';
    if (category == 'system') return 'mensaena_system';
    if (category == 'events' ||
        category == 'marketplace' ||
        category == 'social') {
      return 'mensaena_social';
    }
    return _channelId;
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
    String channelId = _channelId,
  }) async {
    // Channel-spezifische Importance/Priority — muss zum erstellten Channel passen.
    final importance = switch (channelId) {
      'mensaena_calls'  => Importance.max,
      'mensaena_crisis' => Importance.max,
      'mensaena_chat'   => Importance.high,
      'mensaena_social' => Importance.defaultImportance,
      'mensaena_system' => Importance.low,
      _                 => Importance.high,
    };
    final priority = switch (channelId) {
      'mensaena_calls'  => Priority.max,
      'mensaena_crisis' => Priority.max,
      'mensaena_chat'   => Priority.high,
      'mensaena_social' => Priority.defaultPriority,
      'mensaena_system' => Priority.low,
      _                 => Priority.high,
    };
    final silent = channelId == 'mensaena_system';
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: importance,
      priority: priority,
      playSound: !silent,
      enableVibration: !silent,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true, presentBadge: true, presentSound: true,
    );
    await _localNotifications.show(
      id, title, body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  /// FCM-Token holen + in Supabase `fcm_tokens` persistieren.
  /// Letzter Registration-Fehler — fuer UI-Status-Anzeige
  /// (z.B. Settings → Push-Status: "Fehler: <message>").
  static String? lastRegisterError;

  static Future<String?> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        lastRegisterError = 'FCM-Token konnte nicht geholt werden';
        debugPrint('[Push] $lastRegisterError');
        return null;
      }
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) {
        // Token holen ohne User ist OK (vor Login)
        return token;
      }

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
      lastRegisterError = null;
      debugPrint('[Push] Token registriert fuer User $uid');
      return token;
    } catch (e) {
      // BUG-FIX #3: Vorher silent catch → User glaubte Push aktiviert
      lastRegisterError = e.toString();
      debugPrint('[Push] registerToken FAILED: $e');
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
  final isCall = m.data['type'] == 'incoming_call';

  // For non-call messages with notification field: Android renders the
  // system notification itself — return to avoid duplicate.
  if (!isCall && m.notification != null) return;

  try {
    await Firebase.initializeApp();
    final plugin = FlutterLocalNotificationsPlugin();
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
        const InitializationSettings(android: androidInit));

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (isCall) {
      // ── Incoming Call ─────────────────────────────────────────
      // Separate channel with Importance.max + fullScreenIntent so the
      // device shows the call UI on top of the lock-screen, even when
      // the app is killed. 45s timeout = LiveKit room expiry default.
      final callsChannel = AndroidNotificationChannel(
        'mensaena_calls',
        'Eingehende Anrufe',
        description: 'Hochprioritaere Push fuer eingehende DM-Anrufe',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern:
            Int64List.fromList(<int>[0, 1000, 500, 1000, 500, 1000]),
      );
      await androidPlugin?.createNotificationChannel(callsChannel);

      final callerName =
          (m.data['caller_name'] as String?) ?? 'Nachbar:in';
      final callId = (m.data['call_id'] as String?) ?? '';
      final roomName = (m.data['room_name'] as String?) ?? '';
      final peerEnc = Uri.encodeComponent(callerName);
      final roomEnc = Uri.encodeComponent(roomName);
      final deepLink = '/dashboard/call/$callId?room=$roomEnc&peer=$peerEnc';

      final callDetails = AndroidNotificationDetails(
        'mensaena_calls',
        'Eingehende Anrufe',
        channelDescription:
            'Hochprioritaere Push fuer eingehende DM-Anrufe',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
        ongoing: true,
        autoCancel: false,
        vibrationPattern:
            Int64List.fromList(<int>[0, 1000, 500, 1000, 500, 1000]),
        timeoutAfter: 45000,
        icon: '@mipmap/ic_launcher',
        visibility: NotificationVisibility.public,
      );

      await plugin.show(
        callId.hashCode == 0
            ? DateTime.now().millisecondsSinceEpoch
            : callId.hashCode,
        '$callerName ruft an',
        'Tippe um anzunehmen',
        NotificationDetails(android: callDetails),
        payload: deepLink,
      );
      return;
    }

    // ── Regular (non-call) data-only message ─────────────────────
    final title = (m.data['title'] as String?);
    final body = (m.data['body'] as String?);
    if (title == null && body == null) return;

    const defaultChannel = AndroidNotificationChannel(
      'mensaena_default',
      'Mensaena Benachrichtigungen',
      description: 'Nachrichten, Matches und allgemeine Benachrichtigungen',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin?.createNotificationChannel(defaultChannel);

    const defaultDetails = AndroidNotificationDetails(
      'mensaena_default',
      'Mensaena Benachrichtigungen',
      channelDescription:
          'Nachrichten, Matches und allgemeine Benachrichtigungen',
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
      const NotificationDetails(android: defaultDetails),
      payload: m.data['url'] as String?,
    );
  } catch (_) {
    // ignore — App ist im Background, nichts was wir interaktiv tun koennten
  }
}
