/// SKILL: mensaena-design
/// Cinema-Theme Riverpod-Provider — verwaltet Phase, Mode + Intensity.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/theme/cinema_theme.dart';

const _modeStorageKey = 'cinema_mode_v1';
const _intensityStorageKey = 'cinema_intensity_v1';
const _storage = FlutterSecureStorage();

class CinemaModeNotifier extends StateNotifier<CinemaMode> {
  CinemaModeNotifier() : super(CinemaMode.auto) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _modeStorageKey);
      state = CinemaModeX.fromKey(raw);
    } catch (_) {}
  }

  Future<void> set(CinemaMode mode) async {
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
  /// Default = full — Cinema-Effekte voll aktiv.
  /// V20-Architektur: CinemaOverlay ist jetzt persistenter Background-Layer
  /// im DashboardScaffold (statt Body-Wrapper), wird NICHT mehr bei jedem
  /// Tab-Wechsel disposed/rebuild → AnimationControllers laufen stabil.
  /// Damit ist die volle Cinema-Atmosphaere ohne Crash-Risiko aktiv.
  /// User kann auf reduced/minimal runter wenn Battery-Saving gewuenscht.
  CinemaIntensityNotifier() : super(CinemaIntensity.full) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _intensityStorageKey);
      state = CinemaIntensityX.fromKey(raw);
    } catch (_) {}
  }

  Future<void> set(CinemaIntensity intensity) async {
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
