import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistente Accessibility-Einstellungen: Dark-Mode, Schrift-Skalierung,
/// reduzierte Bewegung. Wird in SharedPreferences gespeichert (localStorage-
/// Pendant) und beim Start asynchron eingelesen.
class AccessibilitySettings {
  const AccessibilitySettings({
    this.themeMode = ThemeMode.system,
    this.textScale = 1.0,
    this.reducedMotion = false,
  });

  final ThemeMode themeMode;

  /// Multiplikator für die Standard-Schriftgröße (0.85 – 1.4). 1.0 = Default.
  final double textScale;

  final bool reducedMotion;

  AccessibilitySettings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    bool? reducedMotion,
  }) =>
      AccessibilitySettings(
        themeMode: themeMode ?? this.themeMode,
        textScale: textScale ?? this.textScale,
        reducedMotion: reducedMotion ?? this.reducedMotion,
      );
}

class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  AccessibilityNotifier() : super(const AccessibilitySettings()) {
    _restore();
  }

  static const _kThemeMode = 'a11y.themeMode';
  static const _kTextScale = 'a11y.textScale';
  static const _kReducedMotion = 'a11y.reducedMotion';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIdx = prefs.getInt(_kThemeMode);
      final scale = prefs.getDouble(_kTextScale);
      final reduced = prefs.getBool(_kReducedMotion);
      state = state.copyWith(
        themeMode: modeIdx != null && modeIdx >= 0 && modeIdx < ThemeMode.values.length
            ? ThemeMode.values[modeIdx]
            : ThemeMode.system,
        textScale: scale ?? 1.0,
        reducedMotion: reduced ?? false,
      );
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> setTextScale(double scale) async {
    final clamped = scale.clamp(0.85, 1.4);
    state = state.copyWith(textScale: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTextScale, clamped);
  }

  Future<void> setReducedMotion(bool value) async {
    state = state.copyWith(reducedMotion: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReducedMotion, value);
  }
}

final accessibilityProvider =
    StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
  (ref) => AccessibilityNotifier(),
);
