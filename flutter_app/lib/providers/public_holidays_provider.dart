/// Riverpod-Provider für öffentliche Feiertage via Nager.Date API.
/// Cached autoDispose — kein Speicherleak bei Screen-Verlassen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/holidays_service.dart';

/// Leitet aus dem locale-languageCode einen Nager.Date-CountryCode ab.
/// Fallback: 'DE'.
String countryCodeFromLocale(String languageCode) {
  const Map<String, String> _langToCountry = {
    'de': 'DE',
    'en': 'GB',
    'it': 'IT',
    'es': 'ES',
    'fr': 'FR',
    'tr': 'TR',
    'ru': 'RU',
  };
  return _langToCountry[languageCode] ?? 'DE';
}

/// Family-Key: (countryCode, year) — z. B. ('DE', 2026).
typedef _HolidayKey = ({String countryCode, int year});

final publicHolidaysProvider = FutureProvider.autoDispose
    .family<List<Holiday>, _HolidayKey>((ref, key) async {
  return HolidaysService.forCountry(key.countryCode, year: key.year);
});
