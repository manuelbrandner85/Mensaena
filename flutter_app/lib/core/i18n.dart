import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unterstützte Sprachen — 1:1 zur Web-Konfiguration (next-intl).
const supportedLanguages = <Language>[
  Language('de', 'Deutsch', '🇩🇪'),
  Language('en', 'English', '🇬🇧'),
  Language('it', 'Italiano', '🇮🇹'),
  Language('tr', 'Türkçe', '🇹🇷'),
  Language('uk', 'Українська', '🇺🇦'),
  Language('ar', 'العربية', '🇸🇦'),
];

class Language {
  const Language(this.code, this.label, this.flag);
  final String code;
  final String label;
  final String flag;
}

/// Holt das `Language` zum Code (Fallback: Deutsch).
Language languageFor(String code) => supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => supportedLanguages.first,
    );

List<Language> get languages => supportedLanguages;

/// Riverpod-Provider für die aktuell gewählte Sprache. Persistiert in
/// SharedPreferences unter `i18n.locale`.
final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('de')) {
    _restore();
  }

  static const _kKey = 'i18n.locale';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_kKey);
      if (code != null && supportedLanguages.any((l) => l.code == code)) {
        state = Locale(code);
        await Translations.load(code);
      }
    } catch (_) {}
  }

  Future<void> setLocale(String code) async {
    state = Locale(code);
    await Translations.load(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, code);
  }
}

/// Statische Translation-Map. Wird beim Start asynchron pro gewählter
/// Sprache aus `assets/i18n/<lang>.json` geladen.
///
/// Verwendung im Widget:
///   `Text(t('common.save', defaultText: 'Speichern'))`
class Translations {
  Translations._();

  static Map<String, dynamic> _strings = {};
  static String _activeLocale = 'de';

  static String? get(String key) => _strings[key] as String?;

  /// Lädt das passende ARB/JSON aus dem Asset-Bundle. Bei Fehler bleibt
  /// die vorherige Map aktiv (graceful degradation).
  static Future<void> load(String code) async {
    try {
      final raw = await rootBundle.loadString('assets/i18n/$code.json');
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        _strings = json;
        _activeLocale = code;
      }
    } catch (e, st) {
      debugPrint('Translations.load($code) failed: $e\n$st');
    }
  }

  static String get activeLocale => _activeLocale;
}

/// Convenience-Function für `Translations`.
/// `t('key', defaultText: '…')` — wenn der Key fehlt wird der Default
/// zurückgegeben, sodass die App auch ohne ARB-File funktioniert.
String t(String key, {required String defaultText}) {
  return Translations.get(key) ?? defaultText;
}
