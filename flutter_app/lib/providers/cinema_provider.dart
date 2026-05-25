/// SKILL: mensaena-design
/// Cinema-Theme Riverpod-Provider V2 — Storage-Race eliminiert.
///
/// V1 Problem: _load() feuerte im Constructor (async I/O zum Keystore).
/// State aenderte sich mid-Frame → CinemaOverlay + alle GlassCards
/// rebuilden → Jank beim App-Start.
///
/// V2: _load() wird erst NACH dem ersten Frame getriggert via
/// addPostFrameCallback. UI startet sofort mit Default-Werten,
/// Storage-Update kommt smooth nach dem ersten Paint.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/theme/cinema_theme.dart';

const _modeStorageKey = 'cinema_mode_v1';
const _intensityStorageKey = 'cinema_intensity_v1';
const _storage = FlutterSecureStorage();

class CinemaModeNotifier extends StateNotifier<CinemaMode> {
  CinemaModeNotifier() : super(CinemaMode.auto) {
    // V2: Deferred — nicht im ersten Frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _modeStorageKey);
      final loaded = CinemaModeX.fromKey(raw);
      if (!mounted) return;
      if (loaded != state) state = loaded;
    } catch (_) {}
  }

  Future<void> set(CinemaMode mode) async {
    if (!mounted) return;
    state = mode;
    try {
      await _storage.write(key: _modeStorageKey, value: mode.key);
    } catch (_) {}
  }
}

final cinemaModeProvider =
    StateNotifierProvider<CinemaModeNotifier, CinemaMode>(
        (ref) => CinemaModeNotifier());

class CinemaIntensityNotifier extends StateNotifier<CinemaIntensity> {
  /// V2: Default bleibt minimal. Storage-Read kommt nach erstem Frame.
  CinemaIntensityNotifier() : super(CinemaIntensity.minimal) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _intensityStorageKey);
      final loaded = CinemaIntensityX.fromKey(raw);
      if (!mounted) return;
      if (loaded != state) state = loaded;
    } catch (_) {}
  }

  Future<void> set(CinemaIntensity intensity) async {
    if (!mounted) return;
    state = intensity;
    try {
      await _storage.write(key: _intensityStorageKey, value: intensity.key);
    } catch (_) {}
  }
}

final cinemaIntensityProvider =
    StateNotifierProvider<CinemaIntensityNotifier, CinemaIntensity>(
        (ref) => CinemaIntensityNotifier());

/// Aktuelle Phase basierend auf Uhrzeit. Refresht alle 60s.
final cinemaPhaseProvider = StreamProvider<CinemaPhase>((ref) async* {
  yield CinemaTheme.resolveForTime(DateTime.now());
  final timer = Stream<void>.periodic(const Duration(seconds: 60));
  await for (final _ in timer) {
    yield CinemaTheme.resolveForTime(DateTime.now());
  }
});

/// Effektive Phase (User-Override gewinnt über Auto).
/// Liefert null wenn Mode = off.
final effectiveCinemaPhaseProvider = Provider<CinemaPhase?>((ref) {
  final mode = ref.watch(cinemaModeProvider);
  switch (mode) {
    case CinemaMode.off:
      return null;
    case CinemaMode.forceNight:
      return CinemaPhase.night;
    case CinemaMode.forceDay:
      return CinemaPhase.day;
    case CinemaMode.forceDusk:
      return CinemaPhase.dusk;
    case CinemaMode.auto:
      return ref.watch(cinemaPhaseProvider).value ??
          CinemaTheme.resolveForTime(DateTime.now());
  }
});
