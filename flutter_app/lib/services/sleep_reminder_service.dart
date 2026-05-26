/// SKILL: mensaena-features (P11) — Sleep-Reminder.
/// Daily local notification (zonedSchedule) zur User-gewählten Uhrzeit.
/// Default: 22:00 — sanfter Hinweis "Zeit zum Abschalten".
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class SleepReminderService {
  SleepReminderService._();
  static final SleepReminderService instance = SleepReminderService._();

  static const _storage = FlutterSecureStorage();
  static const _kEnabled = 'sleep_reminder_enabled_v1';
  static const _kHour = 'sleep_reminder_hour_v1';
  static const _kMinute = 'sleep_reminder_min_v1';

  static const _notificationId = 71010;
  static const _channelId = 'mensaena_sleep_reminder';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _tzInitialized = false;

  Future<bool> isEnabled() async {
    final v = await _storage.read(key: _kEnabled);
    return v == '1';
  }

  Future<TimeOfDay> currentTime() async {
    final h = int.tryParse(await _storage.read(key: _kHour) ?? '') ?? 22;
    final m = int.tryParse(await _storage.read(key: _kMinute) ?? '') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> enable({required int hour, required int minute}) async {
    await _storage.write(key: _kEnabled, value: '1');
    await _storage.write(key: _kHour, value: '$hour');
    await _storage.write(key: _kMinute, value: '$minute');
    await _schedule(hour, minute);
  }

  Future<void> disable() async {
    await _storage.write(key: _kEnabled, value: '0');
    try {
      await _plugin.cancel(_notificationId);
    } catch (_) {}
  }

  Future<void> _ensureTzInit() async {
    if (_tzInitialized) return;
    try {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    } catch (_) {}
  }

  Future<void> _schedule(int hour, int minute) async {
    await _ensureTzInit();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Schlaf-Erinnerung',
        channelDescription:
            'Tägliche Erinnerung zur gewählten Zeit zum Abschalten.',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    try {
      await _plugin.zonedSchedule(
        _notificationId,
        'sleep_reminder.title'.tr(),
        'sleep_reminder.body'.tr(),
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[SleepReminder] schedule failed: $e');
    }
  }

  /// Re-schedule beim App-Launch — z.B. nach OTA-Patch oder Reboot.
  Future<void> ensureScheduled() async {
    if (!await isEnabled()) return;
    final t = await currentTime();
    await _schedule(t.hour, t.minute);
  }
}

