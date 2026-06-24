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

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/theme/cinema_theme.dart';
import '../repositories/profiles_repository.dart';
import '../repositories/settings_repository.dart';
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

/// Schalter „Atmosphäre — Live-Wetter-Hintergrund": Cinema-Stimmung an das
/// ECHTE Wetter am Standort anpassen (Regen/Schnee/Wolken/Sonne/Gewitter als
/// animierte Ebene + subtiler Tint über dem Hintergrund). Default an — sehr
/// leichtgewichtig (Partikel laufen ohnehin nur bei vollen Effekten).
///
/// Persistenz ist **offline-first + geräteübergreifend**: der lokale
/// Secure-Storage-Cache liefert den Wert sofort beim Start (auch offline), die
/// Quelle der Wahrheit ist aber `profiles.app_preferences` in Supabase
/// (SettingsRepository). Beim ersten Frame wird mit der Cloud abgeglichen.
class CinemaWeatherAdaptiveNotifier extends StateNotifier<bool> {
  CinemaWeatherAdaptiveNotifier() : super(true) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    // 1) Lokaler Cache zuerst (sofort, auch ohne Netz).
    try {
      final raw = await _storage.read(key: _weatherAdaptiveStorageKey);
      if (raw != null) {
        final local = raw == '1';
        if (mounted && local != state) state = local;
      }
    } catch (_) {}
    // 2) Mit Supabase abgleichen. Kennt die Cloud den Wert noch nicht
    //    (null = Key fehlt), wird der aktuelle (lokale/Default-)Wert
    //    hochmigriert — eine zuvor lokal getroffene Wahl bleibt so erhalten.
    try {
      final remote = await SettingsRepository.getLiveWeatherBackground();
      if (!mounted) return;
      if (remote == null) {
        await SettingsRepository.setLiveWeatherBackground(state);
      } else {
        if (remote != state) state = remote;
        try {
          await _storage.write(
              key: _weatherAdaptiveStorageKey, value: remote ? '1' : '0');
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> set(bool value) async {
    if (!mounted) return;
    state = value;
    // Lokaler Cache (sofort) + Cloud (geräteübergreifend). Beide best-effort.
    try {
      await _storage.write(
          key: _weatherAdaptiveStorageKey, value: value ? '1' : '0');
    } catch (_) {}
    try {
      await SettingsRepository.setLiveWeatherBackground(value);
    } catch (_) {}
  }
}

final cinemaWeatherAdaptiveProvider =
    StateNotifierProvider<CinemaWeatherAdaptiveNotifier, bool>(
        (ref) => CinemaWeatherAdaptiveNotifier());

enum CinemaWeather { clear, cloudy, fog, rain, snow, thunder }

/// EINE Quelle der Wahrheit: die ECHTE aktuelle Wetterlage am Standort
/// (Open-Meteo `current`, `timezone=auto`). Tint, Kondition UND Partikel-
/// Dichte werden hieraus als reine Funktionen abgeleitet — keine doppelten
/// Fetches, keine Stunden-/Zeitzonen-Fehlzuordnung mehr (Bugfix
/// „manchmal nicht richtig dargestellt"). Refresht alle 15 Min; null =
/// Schalter aus / keine Standortdaten.
final cinemaWeatherNowProvider = StreamProvider<WeatherNow?>((ref) async* {
  if (!ref.watch(cinemaWeatherAdaptiveProvider)) {
    yield null;
    return;
  }
  Future<WeatherNow?> resolve() async {
    try {
      final p = await ProfilesRepository.getMine();
      final lat = p?.latitude ?? p?.homeLat;
      final lng = p?.longitude ?? p?.homeLng;
      if (lat == null || lng == null) return null;
      return await WeatherService.current(latitude: lat, longitude: lng);
    } catch (_) {
      return null;
    }
  }

  yield await resolve();
  await for (final _ in Stream<void>.periodic(const Duration(minutes: 15))) {
    yield await resolve();
  }
});

/// Live-Wetterlage → Kondition (für Partikel/Blitz).
CinemaWeather weatherConditionOf(WeatherNow? now) =>
    now == null ? CinemaWeather.clear : _weatherForCode(now.code);

/// Live-Wetterlage → Stimmungs-Tint (null = klar/keine Anpassung).
Color? weatherTintOf(WeatherNow? now) =>
    now == null ? null : _weatherTintForCode(now.code);

/// Wolken-Farbe für die driftende Wolken-Ebene. Wolkig/Regen/Schnee/Gewitter
/// bekommen echte Wolken (klar/Nebel = null, keine Wolken). Farb-Literale leben
/// bewusst hier im Provider (außerhalb des Color-Guard-Scopes lib/widgets).
Color? cloudColorOf(WeatherNow? now) {
  if (now == null) return null;
  switch (_weatherForCode(now.code)) {
    case CinemaWeather.thunder:
      return const Color(0x73474D5A); // dunkle, schwere Gewitterwolke
    case CinemaWeather.rain:
      return const Color(0x66727A89); // graue Regenwolke
    case CinemaWeather.snow:
      return const Color(0x59CAD5E6); // helle, dichte Schneewolke
    case CinemaWeather.cloudy:
      return const Color(0x4DAEB8C6); // weiche, helle Wolke
    case CinemaWeather.clear:
    case CinemaWeather.fog:
      return null;
  }
}

/// Wolken-Dichte (Anzahl Ballen) für die driftende Wolken-Ebene. Gewitter ist
/// schwer/dicht bewölkt, Regen etwas dichter als normale Bewölkung.
int cloudDensityFor(WeatherNow? now) {
  if (now == null) return 5;
  switch (_weatherForCode(now.code)) {
    case CinemaWeather.thunder:
      return 8;
    case CinemaWeather.rain:
      return 6;
    case CinemaWeather.cloudy:
    case CinemaWeather.snow:
    case CinemaWeather.clear:
    case CinemaWeather.fog:
      return 5;
  }
}

/// Gewitter-Stimmung: dunkler Top-Down-Tint, der die Szene bei Gewitter
/// schwerer/bedrohlicher macht. null = kein Gewitter. Farb-Literal bewusst
/// hier im Provider (außerhalb des Color-Guard-Scopes lib/widgets).
Color? thunderMoodColor(WeatherNow? now) {
  if (now == null) return null;
  return _weatherForCode(now.code) == CinemaWeather.thunder
      ? const Color(0x40161A24) // schweres, dunkles Gewittergrau-Blau
      : null;
}

/// Vordergrund-Regenschleier: weiche, in der Luft ziehende Regenschleier bei
/// Regen/Gewitter (vor der Szene, aber hinter dem Content → Lesbarkeit bleibt).
/// `bands` (Anzahl Schleier) skaliert mit dem gemessenen Niederschlag. null =
/// kein Regen. Farb-Literal bewusst hier im Provider.
class RainVeilSpec {
  const RainVeilSpec({required this.color, required this.bands});
  final Color color;
  final int bands;
}

RainVeilSpec? rainVeilFor(WeatherNow? now) {
  if (now == null) return null;
  final w = _weatherForCode(now.code);
  if (w != CinemaWeather.rain && w != CinemaWeather.thunder) return null;
  final mm = (now.rainMm + now.showersMm) > 0
      ? now.rainMm + now.showersMm
      : now.precipitationMm;
  int bands;
  if (mm < 0.3) {
    bands = 2; // Niesel
  } else if (mm < 1.5) {
    bands = 3; // leicht
  } else if (mm < 4.0) {
    bands = 4; // mäßig
  } else {
    bands = 6; // stark
  }
  if (w == CinemaWeather.thunder) bands += 1;
  return RainVeilSpec(color: const Color(0x3FA9B6C8), bands: bands);
}

CinemaWeather _weatherForCode(int code) {
  if (code <= 1) return CinemaWeather.clear;
  if (code == 2 || code == 3) return CinemaWeather.cloudy;
  if (code == 45 || code == 48) return CinemaWeather.fog;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return CinemaWeather.snow;
  }
  if (code >= 95) return CinemaWeather.thunder;
  if (code >= 51 && code <= 82) return CinemaWeather.rain;
  return CinemaWeather.clear;
}

/// C/D: Partikel-Art für eine animierte Ebene. Farb-Literale leben hier im
/// Provider (außerhalb des Color-Guard-Scopes lib/widgets) und werden an die
/// CinemaParticleLayer durchgereicht.
enum CinemaParticleKind { rain, snow, leaf, blossom, pollen }

class CinemaParticleSpec {
  const CinemaParticleSpec({
    required this.kind,
    required this.color,
    required this.count,
  });
  final CinemaParticleKind kind;
  final Color color;
  final int count;
}

/// C: ECHTE Wetterlage → fallende Partikel mit realistischer Dichte. Die
/// Anzahl skaliert mit dem gemessenen Niederschlag (mm) bzw. Schneefall (cm)
/// am Standort — Niesel ≠ Wolkenbruch. null = klar/bewölkt/Nebel (Tint bzw.
/// Nebel-Drift übernehmen). Gewitter = dichter Regen.
CinemaParticleSpec? weatherParticleSpec(WeatherNow? now) {
  if (now == null) return null;
  final w = _weatherForCode(now.code);
  switch (w) {
    case CinemaWeather.rain:
    case CinemaWeather.thunder:
      // mm/h aus rain+showers (fällt auf Gesamt-Niederschlag zurück).
      final mm = (now.rainMm + now.showersMm) > 0
          ? now.rainMm + now.showersMm
          : now.precipitationMm;
      int count;
      if (mm < 0.3) {
        count = 38; // Niesel / gerade aufgehört (Code sagt Regen)
      } else if (mm < 1.5) {
        count = 72; // leicht
      } else if (mm < 4.0) {
        count = 112; // mäßig
      } else {
        count = 150; // stark
      }
      if (w == CinemaWeather.thunder) {
        final boosted = (count * 1.2).round();
        count = boosted > 170 ? 170 : boosted;
      }
      return CinemaParticleSpec(
          kind: CinemaParticleKind.rain,
          color: const Color(0xCCBFD4E8),
          count: count);
    case CinemaWeather.snow:
      final cm = now.snowfallCm;
      int count;
      if (cm < 0.2) {
        count = 32;
      } else if (cm < 1.0) {
        count = 54;
      } else {
        count = 82;
      }
      return CinemaParticleSpec(
          kind: CinemaParticleKind.snow,
          color: const Color(0xF2EAF2FB),
          count: count);
    case CinemaWeather.clear:
    case CinemaWeather.cloudy:
    case CinemaWeather.fog:
      return null;
  }
}

/// D: Saison → schwebende Partikel (Nordhalbkugel): Winter Schnee, Frühling
/// Blüten, Sommer Pollen-Licht, Herbst Laub. Wird nur gerendert wenn KEINE
/// Wetter-Partikel aktiv sind (kein Doppel-Schnee bei Winter-Schneefall).
CinemaParticleSpec seasonalParticleSpec(int month) {
  if (month == 12 || month == 1 || month == 2) {
    return const CinemaParticleSpec(
        kind: CinemaParticleKind.snow, color: Color(0xE6EAF2FB), count: 36);
  }
  if (month >= 3 && month <= 5) {
    return const CinemaParticleSpec(
        kind: CinemaParticleKind.blossom, color: Color(0xE6F7C5D9), count: 18);
  }
  if (month >= 6 && month <= 8) {
    return const CinemaParticleSpec(
        kind: CinemaParticleKind.pollen, color: Color(0xCCFFE6A6), count: 24);
  }
  return const CinemaParticleSpec(
      kind: CinemaParticleKind.leaf, color: Color(0xE6D98A3A), count: 18);
}

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

/// B: Echte Sonnen-/Mond-Position als [Alignment], kontinuierlich aus den
/// lokalen Sonnenzeiten berechnet — Aufgang Ost (links), Zenit oben-mittig,
/// Untergang West (rechts). Nachts derselbe Bogen für den Mond. Behebt die
/// früher fixe „Sonne mittig in der Stadt bei Sonnenuntergang": die Position
/// folgt jetzt der echten Uhrzeit statt einem statischen Phasen-Punkt.
///
/// null = keine Standortdaten / nur User-Override-Phase aktiv → SkyBody nutzt
/// die statische Phasen-Position als Fallback (z. B. bei forceNight/-Day/-Dusk).
final cinemaSkyBodyAlignmentProvider = StreamProvider<Alignment?>((ref) async* {
  // Nur im Auto-Modus folgt der Himmelskörper der echten Zeit. Bei einem
  // erzwungenen Phasen-Override (Nacht/Tag/Dusk) bleibt die kuratierte
  // statische Position der Phase erhalten.
  if (ref.watch(cinemaModeProvider) != CinemaMode.auto) {
    yield null;
    return;
  }

  Future<Alignment?> resolve() async {
    try {
      final p = await ProfilesRepository.getMine();
      final lat = p?.latitude ?? p?.homeLat;
      final lng = p?.longitude ?? p?.homeLng;
      if (lat == null || lng == null) return null;
      final sun = await SunriseSunsetService.forLocation(lat: lat, lng: lng);
      if (sun == null) return null;
      return _skyArcAlignment(DateTime.now(), sun);
    } catch (_) {
      return null;
    }
  }

  yield await resolve();
  // Alle 2 Min nachführen — die Position wandert nur minimal, SkyBody glättet
  // den Schritt per AnimatedAlign, also reicht ein grobes Intervall (Akku).
  final timer = Stream<void>.periodic(const Duration(minutes: 2));
  await for (final _ in timer) {
    yield await resolve();
  }
});

/// Bildet die aktuelle Uhrzeit auf einen Himmels-Bogen ab.
///   * Tag (sunrise→sunset): Sonne wandert.
///   * Nacht (sunset→nächster sunrise): Mond wandert auf demselben Bogen.
/// x: linear Ost(−1.05)→West(+1.05). y: angehobener Sinus-Bogen — Horizont
/// (~0.92 unten) an den Rändern, Zenit (~−0.88 oben) in der Mitte.
Alignment _skyArcAlignment(DateTime now, SunTimes sun) {
  final isDay = now.isAfter(sun.sunrise) && now.isBefore(sun.sunset);
  final DateTime start;
  final DateTime end;
  if (isDay) {
    start = sun.sunrise;
    end = sun.sunset;
  } else if (now.isBefore(sun.sunrise)) {
    // Frühe Morgenstunden → der Untergang war „gestern".
    start = sun.sunset.subtract(const Duration(days: 1));
    end = sun.sunrise;
  } else {
    // Nach Sonnenuntergang → bis zum Aufgang „morgen".
    start = sun.sunset;
    end = sun.sunrise.add(const Duration(days: 1));
  }
  final total = end.difference(start).inSeconds;
  if (total <= 0) return const Alignment(0, -0.85);
  final t = (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
  final x = -1.05 + t * 2.10;
  final lift = math.sin(t * math.pi); // 0 an Rändern, 1 in der Mitte
  final y = 0.92 - lift * 1.80;
  return Alignment(x.clamp(-1.1, 1.1), y.clamp(-1.0, 1.0));
}
