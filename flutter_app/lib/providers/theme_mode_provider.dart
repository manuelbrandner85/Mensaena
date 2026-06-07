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
  ThemeModeNotifier() : super(ThemeMode.light) {
    // Deferred — analog cinema_provider V2. Storage-Read im Constructor
    // (sync I/O) verursachte Mid-Frame-State-Changes beim App-Start.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      final loaded = _fromKey(raw);
      if (!mounted) return;
      if (loaded != state) state = loaded;
    } catch (_) {/* default state ok */}
  }

  /// Setzt den Theme-Mode und persistiert.
  Future<void> set(ThemeMode mode) async {
    if (!mounted) return;
    state = mode;
    try {
      await _storage.write(key: _storageKey, value: _toKey(mode));
    } catch (_) {/* ignore */}
  }

  /// Toggle dark <-> light.
  Future<void> toggle() async {
    if (!mounted) return;
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
      case 'dark':   return ThemeMode.dark;
      case 'light':  return ThemeMode.light;
      case 'system': return ThemeMode.system;
      default:       return ThemeMode.light;
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
