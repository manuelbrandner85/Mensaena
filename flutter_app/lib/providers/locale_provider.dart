/// SKILL: mensaena-features
/// LocaleProvider — verwaltet aktive App-Sprache.
///
/// Zwei Modi (persistiert in flutter_secure_storage):
///   * manual: User wählt explizit eine Sprache aus 7 unterstützten
///     (de/en/it/es/ru/tr/fr).
///   * auto:   Sprache wird beim Start aus GPS-Standort + Country-Code-
///     Mapping ermittelt. Refresh on-demand.
///
/// Default-Mode: manual + Deutsch. Auto wird nur aktiviert, wenn der
/// User es explizit einschaltet (verhindert ungewollten GPS-Prompt
/// beim ersten Launch).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/locale_detection_service.dart';

const _modeKey = 'locale_mode_v1';
const _manualLangKey = 'locale_manual_v1';
const _storage = FlutterSecureStorage();

/// Unsere 7 unterstützten App-Sprachen.
const List<Locale> kSupportedLocales = [
  Locale('de'),
  Locale('en'),
  Locale('it'),
  Locale('es'),
  Locale('fr'),
  Locale('tr'),
  Locale('ru'),
];

const Locale kFallbackLocale = Locale('de');

enum LocaleMode { manual, auto }

extension LocaleModeX on LocaleMode {
  String get key => this == LocaleMode.auto ? 'auto' : 'manual';
  static LocaleMode fromKey(String? k) =>
      k == 'auto' ? LocaleMode.auto : LocaleMode.manual;
}

class LocaleState {
  const LocaleState({
    required this.mode,
    required this.activeLocale,
    this.detectedLocale,
  });

  final LocaleMode mode;
  final Locale activeLocale;

  /// Letzte über GPS ermittelte Sprache — nur im Auto-Modus relevant.
  /// Wird auch im Manual-Modus gesetzt, sobald detect() läuft (UI-Anzeige).
  final Locale? detectedLocale;

  LocaleState copyWith({
    LocaleMode? mode,
    Locale? activeLocale,
    Locale? detectedLocale,
  }) =>
      LocaleState(
        mode: mode ?? this.mode,
        activeLocale: activeLocale ?? this.activeLocale,
        detectedLocale: detectedLocale ?? this.detectedLocale,
      );
}

class LocaleNotifier extends StateNotifier<LocaleState> {
  LocaleNotifier()
      : super(const LocaleState(
          mode: LocaleMode.manual,
          activeLocale: kFallbackLocale,
        )) {
    _load();
  }

  Future<void> _load() async {
    try {
      final mode = LocaleModeX.fromKey(await _storage.read(key: _modeKey));
      final manualLang =
          await _storage.read(key: _manualLangKey) ?? 'de';
      final manualLocale = _localeForCode(manualLang);
      state = LocaleState(
        mode: mode,
        activeLocale: manualLocale,
      );
      // Bei Auto: GPS-Detect im Hintergrund auslösen.
      if (mode == LocaleMode.auto) {
        await _runDetect(applyToActive: true);
      }
    } catch (_) {/* default state ok */}
  }

  /// User wählt manuell eine Sprache.
  Future<void> setManual(Locale l, BuildContext? context) async {
    state = state.copyWith(mode: LocaleMode.manual, activeLocale: l);
    await _storage.write(key: _modeKey, value: LocaleMode.manual.key);
    await _storage.write(key: _manualLangKey, value: l.languageCode);
    if (context != null && context.mounted) {
      await context.setLocale(l);
    }
  }

  /// Schaltet Auto-Modus an oder aus.
  Future<void> setAuto(bool enabled, BuildContext? context) async {
    if (!enabled) {
      // Fallback: bleibe bei zuletzt gespeicherter manueller Sprache.
      final stored =
          await _storage.read(key: _manualLangKey) ?? 'de';
      final locale = _localeForCode(stored);
      state = state.copyWith(mode: LocaleMode.manual, activeLocale: locale);
      await _storage.write(key: _modeKey, value: LocaleMode.manual.key);
      if (context != null && context.mounted) {
        await context.setLocale(locale);
      }
      return;
    }
    state = state.copyWith(mode: LocaleMode.auto);
    await _storage.write(key: _modeKey, value: LocaleMode.auto.key);
    // ignore: use_build_context_synchronously
    await _runDetect(applyToActive: true, context: context);
  }

  /// Manuell GPS-Detect erneut ausführen (für Refresh-Button in UI).
  Future<void> refreshDetected(BuildContext? context) async {
    await _runDetect(
        applyToActive: state.mode == LocaleMode.auto, context: context);
  }

  Future<void> _runDetect(
      {required bool applyToActive, BuildContext? context}) async {
    final detected = await LocaleDetectionService.detect();
    if (detected == null) {
      state = state.copyWith(detectedLocale: null);
      return;
    }
    final supported = _matchSupported(detected);
    state = state.copyWith(detectedLocale: supported);
    if (applyToActive) {
      state = state.copyWith(activeLocale: supported);
      final ctx = context;
      if (ctx != null && ctx.mounted) {
        // ignore: use_build_context_synchronously
        await ctx.setLocale(supported);
      }
    }
  }

  Locale _matchSupported(Locale l) {
    for (final s in kSupportedLocales) {
      if (s.languageCode == l.languageCode) return s;
    }
    return kFallbackLocale;
  }

  Locale _localeForCode(String code) {
    for (final s in kSupportedLocales) {
      if (s.languageCode == code) return s;
    }
    return kFallbackLocale;
  }
}

final localeProvider =
    StateNotifierProvider<LocaleNotifier, LocaleState>((ref) {
  return LocaleNotifier();
});
