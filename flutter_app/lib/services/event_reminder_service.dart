/// SKILL: mensaena-features (UX-Welle1 E2)
/// Lokale Erinnerungs-Notifications für gespeicherte Events.
/// `schedule(eventId, eventStart, minutesBefore, title, body)` plant
/// eine einmalige Notification, `cancel(eventId)` löscht sie wieder.
/// Notification-ID wird deterministisch aus dem eventId-Hash abgeleitet
/// (positives 31-Bit-Int) — kein Tracking-Storage nötig.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class EventReminderService {
  const EventReminderService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _tzReady = false;

  static const _channelId = 'mensaena_event_reminders';

  static int _idForEvent(String eventId) {
    final h = eventId.hashCode;
    return h & 0x7fffffff;
  }

  static Future<void> _ensureTz() async {
    if (_tzReady) return;
    try {
      tzdata.initializeTimeZones();
      _tzReady = true;
    } catch (_) {}
  }

  static Future<void> schedule({
    required String eventId,
    required DateTime eventStart,
    required int minutesBefore,
    required String title,
  }) async {
    await _ensureTz();
    final fireUtc = eventStart
        .toUtc()
        .subtract(Duration(minutes: minutesBefore));
    if (fireUtc.isBefore(DateTime.now().toUtc())) return;
    final fireTz = tz.TZDateTime.from(fireUtc, tz.local);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'event_reminders.channelName'.tr(),
        channelDescription: 'event_reminders.channelDescription'.tr(),
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    try {
      await _plugin.zonedSchedule(
        _idForEvent(eventId),
        'event_reminders.title'.tr(),
        'event_reminders.body'
            .tr(namedArgs: {'title': title, 'minutes': '$minutesBefore'}),
        fireTz,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'event:$eventId',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[EventReminder] schedule failed: $e');
    }
  }

  static Future<void> cancel(String eventId) async {
    try {
      await _plugin.cancel(_idForEvent(eventId));
    } catch (_) {}
  }
}
