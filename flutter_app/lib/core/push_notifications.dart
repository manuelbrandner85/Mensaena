import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'supabase.dart';

/// Top-level Handler für Push-Messages im Background. Muss top-level oder
/// static sein (Isolate-Anforderung von firebase_messaging).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Background-Verarbeitung passiert in einem separaten Isolate; wir
  // initialisieren Firebase explizit und loggen den Notification-Empfang.
  // Echte Display-Logik passiert via dem System (data+notification payload).
  await Firebase.initializeApp();
  debugPrint('FCM bg: ${message.messageId} ${message.notification?.title}');
}

/// Cloud-Messaging-Service: einmaliger Init in main(), Token-Persistierung
/// in `fcm_tokens` Supabase-Tabelle, Foreground-Handler mit lokaler
/// Notification-Anzeige.
class PushNotifications {
  PushNotifications._();

  static final _local = FlutterLocalNotificationsPlugin();
  static const _androidChannel = AndroidNotificationChannel(
    'mensaena_default',
    'Mensaena Benachrichtigungen',
    description: 'Allgemeine Push-Nachrichten von Mensaena',
    importance: Importance.high,
  );

  static bool _initialized = false;

  /// Initialisiert Firebase + Local-Notifications + setzt Listener.
  /// Soll von main() VOR runApp aufgerufen werden. Idempotent.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();

      // Background-Handler binden — muss BEVOR irgendein listen passiert.
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      // Permission-Request — iOS interaktiv, Android 13+ ebenfalls Prompt.
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        'FCM permission: ${settings.authorizationStatus}',
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      // Local-Notifications für Foreground-Display.
      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);

      // Foreground-Handler: zeigt eigene lokale Notification, da iOS-System
      // sonst keine Banner anzeigt wenn die App offen ist.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      _initialized = true;
    } catch (e, st) {
      debugPrint('PushNotifications.init failed: $e\n$st');
    }
  }

  /// Holt den FCM-Token (neu nach Login) und schreibt ihn in
  /// `fcm_tokens`. Idempotent: bei bereits gespeichertem Token
  /// wird `last_used` aktualisiert.
  static Future<void> registerToken() async {
    if (!_initialized) return;
    try {
      final user = sb.auth.currentUser;
      if (user == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final pkg = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';

      // Upsert: bei bestehendem (user_id,token) wird active+last_used aktualisiert.
      final existing = await sb
          .from('fcm_tokens')
          .select('id')
          .eq('user_id', user.id)
          .eq('token', token)
          .maybeSingle();
      if (existing != null) {
        await sb.from('fcm_tokens').update({
          'active': true,
          'last_used': DateTime.now().toUtc().toIso8601String(),
          'app_version': '${pkg.version}+${pkg.buildNumber}',
        }).eq('id', existing['id'] as String);
        return;
      }
      await sb.from('fcm_tokens').insert({
        'user_id': user.id,
        'token': token,
        'platform': platform,
        'app_version': '${pkg.version}+${pkg.buildNumber}',
        'device_info': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'active': true,
        'last_used': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, st) {
      debugPrint('PushNotifications.registerToken failed: $e\n$st');
    }
  }

  static Future<void> _onForegroundMessage(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    await _local.show(
      msg.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mensaena_default',
          'Mensaena Benachrichtigungen',
          channelDescription: 'Allgemeine Push-Nachrichten von Mensaena',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }
}
