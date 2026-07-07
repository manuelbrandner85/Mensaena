/// SKILL: mensaena-features
/// date.nager.at — kostenfreie internationale Feiertage-API.
/// https://date.nager.at/swagger/index.html
library;

import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

class Holiday {
  const Holiday({
    required this.date,
    required this.localName,
    required this.name,
    this.countryCode,
    this.global,
    this.types,
  });

  final DateTime date;
  final String localName;
  final String name;
  final String? countryCode;
  final bool? global;
  final List<String>? types;

  bool get isToday {
    final n = DateTime.now();
    return date.year == n.year && date.month == n.month && date.day == n.day;
  }

  int get daysFromNow {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final d = DateTime(date.year, date.month, date.day);
    return d.difference(today).inDays;
  }
}

class HolidaysService {
  const HolidaysService._();

  /// Parst ein API-Datum ('2026-07-06') als *floating date*: nur Jahr/Monat/Tag,
  /// als lokales `DateTime(y, m, d)` (Mitternacht). So bleibt der Feiertag
  /// unabhängig von der Zeitzone auf dem korrekten Kalendertag — `.toUtc()`
  /// hätte ihn je nach Offset auf den Vor-/Folgetag verschoben.
  @visibleForTesting
  static DateTime parseFloatingDate(String raw) {
    final parts = raw.split('T').first.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return DateTime(y, m, d);
  }

  /// Holt Feiertage eines Jahres für einen Country-Code (z. B. 'DE', 'AT').
  static Future<List<Holiday>> forCountry(String countryCode,
      {int? year}) async {
    final y = year ?? DateTime.now().year;
    try {
      final uri =
          Uri.parse('https://date.nager.at/api/v3/PublicHolidays/$y/$countryCode');
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return const [];
      final list = json.decode(r.body) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => Holiday(
                date: parseFloatingDate(m['date'] as String),
                localName: m['localName'] as String? ?? '',
                name: m['name'] as String? ?? '',
                countryCode: m['countryCode'] as String?,
                global: m['global'] as bool?,
                types: (m['types'] as List?)?.cast<String>(),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Nächste 3 anstehende Feiertage.
  static Future<List<Holiday>> upcoming(String countryCode,
      {int max = 3}) async {
    final n = DateTime.now();
    final thisYear = await forCountry(countryCode, year: n.year);
    final filtered = thisYear.where((h) => h.daysFromNow >= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (filtered.length >= max) return filtered.take(max).toList();
    // Auch ins nächste Jahr schauen.
    final next = await forCountry(countryCode, year: n.year + 1);
    return [...filtered, ...next].take(max).toList();
  }
}
