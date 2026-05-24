/// SKILL: mensaena-design
/// ThemeModeProvider (V20 Phase-6b) — verwaltet Dark/Light/System-Toggle.
///
/// Persistiert via flutter_secure_storage (Key: `mensaena_theme_mode_v1`,
/// Werte: `system` | `dark` | `light`). Default: `system`.
///
/// MaterialApp.router liest `themeMode` direkt aus diesem Provider und
/// nutzt `AnimatedTheme` (Flutter built-in) für den weichen CrossFade
/// zwischen den Themes — kein eigener Code nötig.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storageKey = 'mensaena_theme_mode_v1';
const _storage = FlutterSecureStorage();

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      state = _fromKey(raw);
    } catch (_) {
      // Default state ok bei Storage-Fehler (Web/Tests ohne Plugin).
    }
  }

  /// Setzt den Theme-Mode und persistiert.
  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await _storage.write(key: _storageKey, value: _toKey(mode));
    } catch (_) {/* ignore */}
  }

  /// Toggle dark <-> light (System wird in dark gewechselt).
  Future<void> toggle() async {
    switch (state) {
      case ThemeMode.dark:
        await set(ThemeMode.light);
        break;
      case ThemeMode.light:
      case ThemeMode.system:
        await set(ThemeMode.dark);
        break;
    }
  }

  static String _toKey(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:   return 'dark';
      case ThemeMode.light:  return 'light';
      case ThemeMode.system: return 'system';
    }
  }

  static ThemeMode _fromKey(String? k) {
    switch (k) {
      case 'dark':  return ThemeMode.dark;
      case 'light': return ThemeMode.light;
      case 'system':
      default:      return ThemeMode.system;
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
        (ref) => ThemeModeNotifier());

/// Hilfs-Provider: ist der effektiv aktive Mode "light" — beruecksichtigt
/// System-Setting. Wird vom CinemaOverlay genutzt, um Effekt-Intensitaet
/// im Light-Mode zu reduzieren.
final isLightModeProvider = Provider<bool>((ref) {
  final mode = ref.watch(themeModeProvider);
  switch (mode) {
    case ThemeMode.light:
      return true;
    case ThemeMode.dark:
      return false;
    case ThemeMode.system:
      final platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return platformBrightness == Brightness.light;
  }
});
