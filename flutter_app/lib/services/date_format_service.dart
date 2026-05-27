/// SKILL: mensaena-architektur (Phase 0 L51)
/// Zentrale Datums-/Zeit-Formatierung für die ganze App.
/// Konsistente deutsche Schreibweise, mit Auto-Lokalisierung über
/// easy_localization. Vermeidet überall verstreutes DateFormat(...).
library;

import 'package:easy_localization/easy_localization.dart';

class DateFormatService {
  const DateFormatService._();

  /// Relative Zeit: "vor 3 Min." / "vor 2 Std." / "Gestern" / "12. Mai".
  static String relative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'time.justNow'.tr();
    if (diff.inMinutes < 60) {
      return 'time.minutesAgo'.tr(namedArgs: {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'time.hoursAgo'.tr(namedArgs: {'n': '${diff.inHours}'});
    }
    if (diff.inDays == 1) return 'time.yesterday'.tr();
    if (diff.inDays < 7) {
      return 'time.daysAgo'.tr(namedArgs: {'n': '${diff.inDays}'});
    }
    if (dt.year == now.year) return DateFormat('d. MMM', 'de').format(dt);
    return DateFormat('d. MMM yyyy', 'de').format(dt);
  }

  /// Kurzes Datum: "12.05.2026"
  static String shortDate(DateTime dt) =>
      DateFormat('dd.MM.yyyy', 'de').format(dt);

  /// Langes Datum: "12. Mai 2026"
  static String longDate(DateTime dt) =>
      DateFormat('d. MMMM yyyy', 'de').format(dt);

  /// Uhrzeit: "14:32"
  static String time(DateTime dt) => DateFormat('HH:mm', 'de').format(dt);

  /// Datum + Zeit: "12. Mai 2026, 14:32"
  static String dateTime(DateTime dt) =>
      '${longDate(dt)}, ${time(dt)}';

  /// Wochentag-Kurz + Datum: "Di, 12.05."
  static String weekdayShort(DateTime dt) =>
      DateFormat('EEE, dd.MM.', 'de').format(dt);

  /// Wochentag-Lang: "Dienstag, 12. Mai 2026"
  static String weekdayLong(DateTime dt) =>
      DateFormat('EEEE, d. MMMM yyyy', 'de').format(dt);

  /// ISO-8601 für API-Calls (UTC).
  static String iso(DateTime dt) => dt.toUtc().toIso8601String();

  /// Dauer als "MM:SS" oder "HH:MM:SS" für Anrufe + Aufnahmen.
  static String duration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}
