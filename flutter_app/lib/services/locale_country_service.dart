/// SKILL: mensaena-features + mensaena-architektur
/// LocaleCountryService — zentrales Mapping von App-Locale auf ISO-2-Country.
///
/// Wird von allen locale-adaptiven Daten-Modulen (Notruf, MeteoAlarm,
/// Foodbanks, Civil-Protection, Job-Portale, Mental-Support, …) genutzt,
/// damit das User-Land an genau EINER Stelle definiert ist (DRY).
///
/// Priorität:
///   1. `context.locale.countryCode` (z.B. `de_AT` → `AT`)
///   2. Language-Default-Mapping (`de` → `DE`, `en` → `GB`, …)
///   3. Hard-Fallback: `DE`
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

class LocaleCountryService {
  const LocaleCountryService._();

  /// Default-Mapping Sprache → primäres Land mit relevanten Daten.
  /// `en` ist absichtlich auf `GB` gemappt (nicht US), weil unsere
  /// Notruf-/Foodbanks-/MeteoAlarm-Quellen primär europäisch sind.
  static const Map<String, String> defaultByLanguage = {
    'de': 'DE',
    'en': 'GB',
    'it': 'IT',
    'es': 'ES',
    'fr': 'FR',
    'tr': 'TR',
    'ru': 'RU',
  };

  /// Aktuelles "User-Land" als ISO-2 Country Code (UPPERCASE).
  static String forContext(BuildContext context) {
    final loc = context.locale;
    final c = loc.countryCode;
    if (c != null && c.isNotEmpty) return c.toUpperCase();
    return defaultByLanguage[loc.languageCode] ?? 'DE';
  }

  /// Variante, die nur dann ein Land liefert, wenn die Locale wirklich
  /// einem bekannten Mapping zugeordnet werden kann (sonst `null`).
  /// Nützlich für optionale Features (z.B. Civil-Protection-Tile).
  static String? forContextOrNull(BuildContext context) {
    final loc = context.locale;
    final c = loc.countryCode;
    if (c != null && c.isNotEmpty) return c.toUpperCase();
    return defaultByLanguage[loc.languageCode];
  }
}
