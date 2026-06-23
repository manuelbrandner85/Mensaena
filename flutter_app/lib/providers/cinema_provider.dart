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
import '../repositories/profiles_repository.dart';
import '../services/sunrise_sunset_service.dart';
import '../services/weather_service.dart';

const _modeStorageKey = 'cinema_mode_v1';
const _intensityStorageKey = 'cinema_intensity_v1';
const _forceFullStorageKey = 'cinema_force_full_v1';
const _storage = FlutterSecureStorage();

/// User-Override: erzwingt die VOLLEN Kino-Effekte (Sonne/Mond, Partikel,
/// Film-Korn, Nebel, God-Rays …) auch auf als „schwach" erkannten Geräten
/// (Lite-Mode) und ignoriert den Frame-Watchdog-Deckel. Bewusst opt-in mit
/// Warnung — kann auf RAM-schwachen Geräten ruckeln/Akku kosten. A11y
/// (reduceMotion) gewinnt weiterhin.
class ForceFullEffectsNotifier extends StateNotifier<bool> {
  ForceFullEffectsNotifier() : super(false) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _forceFullStorageKey);
      final loaded = raw == '1';
      if (!mounted) return;
      if (loaded != state) state = loaded;
    } catch (_) {}
  }

  Future<void> set(bool value) async {
    if (!mounted) return;
    state = value;
    try {
      await _storage.write(key: _forceFullStorageKey, value: value ? '1' : '0');
    } catch (_) {}
  }
}

final forceFullEffectsProvider =
    StateNotifierProvider<ForceFullEffectsNotifier, bool>(
        (ref) => ForceFullEffectsNotifier());

const _strengthStorageKey = 'cinema_effect_strength_v1';

/// Feinregler 0–100 % für die Stärke der atmosphärischen Cinema-Ebenen
/// (Multiplikator auf die Overlay-Intensität — ergänzt die groben Stufen
/// full/reduced/minimal um stufenlose Kontrolle). Default 100 %.
class CinemaEffectStrengthNotifier extends StateNotifier<int> {
  CinemaEffectStrengthNotifier() : super(100) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _strengthStorageKey);
      final loaded = int.tryParse(raw ?? '') ?? 100;
      final clamped = loaded.clamp(0, 100);
      if (!mounted) return;
      if (clamped != state) state = clamped;
    } catch (_) {}
  }

  Future<void> set(int value) async {
    final clamped = value.clamp(0, 100);
    if (!mounted) return;
    state = clamped;
    try {
      await _storage.write(key: _strengthStorageKey, value: '$clamped');
    } catch (_) {}
  }
}

final cinemaEffectStrengthProvider =
    StateNotifierProvider<CinemaEffectStrengthNotifier, int>(
        (ref) => CinemaEffectStrengthNotifier());

const _weatherAdaptiveStorageKey = 'cinema_weather_adaptive_v1';

/// Schalter: Cinema-Stimmung an das ECHTE Wetter am Standort anpassen
/// (Regen/Nebel/Schnee/Gewitter legen einen subtilen Tint über den
/// Hintergrund). Default an — sehr leichtgewichtig (eine Farb-Ebene).
class CinemaWeatherAdaptiveNotifier extends StateNotifier<bool> {
  CinemaWeatherAdaptiveNotifier() : super(true) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _weatherAdaptiveStorageKey);
      final loaded = raw == null ? true : raw == '1';
      if (!mounted) return;
      if (loaded != state) state = loaded;
    } catch (_) {}
  }

  Future<void> set(bool value) async {
    if (!mounted) return;
    state = value;
    try {
      await _storage.write(
          key: _weatherAdaptiveStorageKey, value: value ? '1' : '0');
    } catch (_) {}
  }
}

final cinemaWeatherAdaptiveProvider =
    StateNotifierProvider<CinemaWeatherAdaptiveNotifier, bool>(
        (ref) => CinemaWeatherAdaptiveNotifier());

/// Aktueller Wetter-Tint (Farbe inkl. Alpha) basierend auf der WMO-Wetterlage
/// am Standort; null = klar / keine Anpassung. Refresht alle 20 Minuten.
final cinemaWeatherTintProvider = StreamProvider<Color?>((ref) async* {
  Future<Color?> resolve() async {
    try {
      final p = await ProfilesRepository.getMine();
      final lat = p?.latitude ?? p?.homeLat;
      final lng = p?.longitude ?? p?.homeLng;
      if (lat == null || lng == null) return null;
      final hours =
          await WeatherService.hourly(latitude: lat, longitude: lng);
      if (hours.isEmpty) return null;
      return _weatherTintForCode(hours.first.code);
    } catch (_) {
      return null;
    }
  }

  yield await resolve();
  await for (final _ in Stream<void>.periodic(const Duration(minutes: 20))) {
    yield await resolve();
  }
});

const _parallaxStorageKey = 'cinema_parallax_v1';

/// Schalter: Parallax/Neige-Tiefe — der Hintergrund verschiebt sich subtil
/// beim Neigen des Geräts (Sensor). Default AUS (opt-in); nur bei vollen
/// Effekten aktiv, sonst kein Sensor/keine Last.
class CinemaParallaxNotifier extends StateNotifier<bool> {
  CinemaParallaxNotifier() : super(false) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _parallaxStorageKey);
      final loaded = raw == '1';
      if (!mounted) return;
      if (loaded != state) state = loaded;
    } catch (_) {}
  }

  Future<void> set(bool value) async {
    if (!mounted) return;
    state = value;
    try {
      await _storage.write(key: _parallaxStorageKey, value: value ? '1' : '0');
    } catch (_) {}
  }
}

final cinemaParallaxProvider =
    StateNotifierProvider<CinemaParallaxNotifier, bool>(
        (ref) => CinemaParallaxNotifier());

const _seasonalStorageKey = 'cinema_seasonal_v1';

/// Schalter: dezente saisonale Stimmung (Winter-Kühle, Frühlingsgrün,
/// Sommer-Gold, Herbst-Bernstein) als Tint über den Hintergrund. Default an,
/// leichtgewichtig (datumsbasiert, keine Netzwerk-/Animationslast).
class CinemaSeasonalNotifier extends StateNotifier<bool> {
  CinemaSeasonalNotifier() : super(true) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _seasonalStorageKey);
      final loaded = raw == null ? true : raw == '1';
      if (!mounted) return;
      if (loaded != state) state = loaded;
    } catch (_) {}
  }

  Future<void> set(bool value) async {
    if (!mounted) return;
    state = value;
    try {
      await _storage.write(key: _seasonalStorageKey, value: value ? '1' : '0');
    } catch (_) {}
  }
}

final cinemaSeasonalProvider =
    StateNotifierProvider<CinemaSeasonalNotifier, bool>(
        (ref) => CinemaSeasonalNotifier());

/// Monat (1–12) → saisonaler Stimmungs-Tint (Nordhalbkugel, Alpha im Hex).
Color? seasonalTintForMonth(int month) {
  if (month == 12 || month == 1 || month == 2) {
    return const Color(0x16CEE0F2); // Winter — kühles Blauweiß
  }
  if (month >= 3 && month <= 5) {
    return const Color(0x120FB07A); // Frühling — frisches Grün
  }
  if (month >= 6 && month <= 8) {
    return const Color(0x14FFCF7A); // Sommer — warmes Gold
  }
  return const Color(0x18D98A3A); // Herbst — Bernstein
}

/// WMO-Wettercode → subtiler Stimmungs-Tint (Alpha im Hex enthalten).
Color? _weatherTintForCode(int code) {
  if (code <= 1) return null; // klar / überwiegend klar
  if (code == 2 || code == 3) return const Color(0x12889098); // bewölkt
  if (code == 45 || code == 48) return const Color(0x24B0B4BA); // Nebel
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return const Color(0x20D8E4F0); // Schnee
  }
  if (code >= 95) return const Color(0x30243042); // Gewitter
  if (code >= 51 && code <= 82) return const Color(0x2435506E); // Regen
  return null;
}

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

/// Aktuelle Phase basierend auf echter Sonne (wenn GPS verfuegbar) oder
/// Uhrzeit (Fallback). Refresht alle 60s.
///
/// Sonnen-Modus: dawn = civil_twilight_begin..sunrise,
/// morning = sunrise..solar_noon-2h,
/// day = solar_noon-2h..sunset-2h,
/// dusk = sunset-2h..civil_twilight_end,
/// evening = civil_twilight_end..civil_twilight_begin+8h,
/// night = sonst.
final cinemaPhaseProvider = StreamProvider<CinemaPhase>((ref) async* {
  Future<CinemaPhase> resolve() async {
    try {
      final p = await ProfilesRepository.getMine();
      final lat = p?.latitude ?? p?.homeLat;
      final lng = p?.longitude ?? p?.homeLng;
      if (lat != null && lng != null) {
        final sun = await SunriseSunsetService.forLocation(lat: lat, lng: lng);
        if (sun != null) {
          return _phaseFromSun(DateTime.now(), sun);
        }
      }
    } catch (_) {/* fall back to time */}
    return CinemaTheme.resolveForTime(DateTime.now());
  }

  yield await resolve();
  final timer = Stream<void>.periodic(const Duration(seconds: 60));
  await for (final _ in timer) {
    yield await resolve();
  }
});

CinemaPhase _phaseFromSun(DateTime now, SunTimes sun) {
  final n = now;
  if (n.isAfter(sun.civilTwilightBegin) && n.isBefore(sun.sunrise)) {
    return CinemaPhase.dawn;
  }
  if (n.isAfter(sun.sunrise) &&
      n.isBefore(sun.solarNoon.subtract(const Duration(hours: 2)))) {
    return CinemaPhase.morning;
  }
  if (n.isAfter(sun.solarNoon.subtract(const Duration(hours: 2))) &&
      n.isBefore(sun.sunset.subtract(const Duration(hours: 2)))) {
    return CinemaPhase.day;
  }
  if (n.isAfter(sun.sunset.subtract(const Duration(hours: 2))) &&
      n.isBefore(sun.civilTwilightEnd)) {
    return CinemaPhase.dusk;
  }
  if (n.isAfter(sun.civilTwilightEnd) &&
      n.isBefore(sun.civilTwilightEnd.add(const Duration(hours: 3)))) {
    return CinemaPhase.evening;
  }
  return CinemaPhase.night;
}

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
