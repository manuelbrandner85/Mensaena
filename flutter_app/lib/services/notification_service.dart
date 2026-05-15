import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Lokale Notifications-Wrapper (Pendant zum bestehenden push_notifications.dart).
/// Wird vom Foreground-Handler in firebase_messaging genutzt um eine sichtbare
/// Notification zu zeigen, wenn die App offen ist.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    _ready = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    const android = AndroidNotificationDetails(
      'mensaena_default',
      'Mensaena',
      channelDescription: 'Mensaena Benachrichtigungen',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: android, iOS: ios),
      payload: payload,
    );
  }
}
