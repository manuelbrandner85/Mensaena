/// SKILL: mensaena-design (Cinema-Hyperreal / Phase-5-Fundament)
/// EffectsGate — DIE eine Wahrheit für "darf dieser Effekt laufen?".
///
/// Fusioniert alle Qualitäts-Signale zu genau einem [EffectsProfile]:
///   DeviceTier (lite/standard)  ×  CinemaIntensity (User-Setting)
///   ×  reduceMotion (A11y)      ×  disableAnimations (System)
///
/// Regeln (strengstes Signal gewinnt):
///   - reduceMotion ODER System-disableAnimations  → none
///   - Lite-Tier ODER CinemaIntensity.minimal      → höchstens reduced…
///     (Lite + minimal → none)
///   - sonst: CinemaIntensity 1:1 (full/reduced)
///
/// Verwendung in Effekt-Widgets (statt eigener Streu-Checks):
///   final profile = ref.watch(effectsProfileProvider);
///   if (profile == EffectsProfile.none) return child;          // aus
///   final blur = profile == EffectsProfile.full ? 18.0 : 0.0;  // reduziert
///
/// Krisen-Screens nutzen Effekte gar nicht erst (Design-Beschluss) —
/// das Gate ist die Obergrenze, kein Ersatz für Kontext-Disziplin.
///
/// Phase 6 dockt hier an: der Frame-Watchdog (QualityController) wird
/// dieses Profil zur Laufzeit zusätzlich herabstufen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme/cinema_theme.dart';
import '../services/device_tier_service.dart';
import 'accessibility_provider.dart';
import 'cinema_provider.dart';

/// Drei Stufen statt vieler Bool-Flags — jeder Effekt mappt selbst,
/// was "reduced" für ihn heißt (Blur aus, statischer Gradient, …).
enum EffectsProfile { none, reduced, full }

extension EffectsProfileX on EffectsProfile {
  bool get isOff => this == EffectsProfile.none;
  bool get isFull => this == EffectsProfile.full;

  /// Multiplikator für Intensitäten (Glow-Alpha, Partikel-Anzahl, …).
  double get intensityFactor => switch (this) {
        EffectsProfile.full => 1.0,
        EffectsProfile.reduced => 0.5,
        EffectsProfile.none => 0.0,
      };
}

/// Laufzeit-Deckel vom FrameWatchdog (Phase 6): true = das Gerät kommt
/// aktuell nicht hinterher → full wird auf reduced gedeckelt. Der Watchdog
/// nimmt nur Schmuck weg, nie Funktion (deshalb kein Deckel auf none).
final runtimeEffectsCapProvider = StateProvider<bool>((_) => false);

/// Crash-Schutz-Deckel vom MemoryWatchdog: true = der Bild-Cache/RAM wird
/// knapp (proaktiv ab ~85 % bzw. akut bei OS-Speicherdruck). Effekte werden
/// AUTOMATISCH auf reduced gedrosselt — bevor das System die App OOM-killt.
/// Wirkt AUCH wenn der User „Maximale Effekte" erzwungen hat.
final memoryEffectsCapProvider = StateProvider<bool>((_) => false);

/// Kombiniertes Sicherheits-Signal: Gerät kommt nicht hinterher (Jank) ODER
/// RAM wird knapp. Beide drosseln Effekte zum Crash-Schutz.
final effectsSafetyCapProvider = Provider<bool>((ref) =>
    ref.watch(runtimeEffectsCapProvider) ||
    ref.watch(memoryEffectsCapProvider));

final effectsProfileProvider = Provider<EffectsProfile>((ref) {
  // effectiveReduceMotion: schließt seniorMode mit ein.
  final reduceMotion = ref.watch(a11yProvider).effectiveReduceMotion;
  if (reduceMotion) return EffectsProfile.none;

  // Crash-Schutz: Jank (FrameWatchdog) ODER knapper RAM (MemoryWatchdog)
  // deckeln Effekte AUTOMATISCH auf reduced — bevor die App crasht.
  final safetyCap = ref.watch(effectsSafetyCapProvider);

  // User-Override „Maximale Kino-Effekte": volle Effekte trotz Lite-Tier —
  // ABER der Crash-Schutz greift weiterhin (sonst killt das System die App).
  // A11y/reduceMotion (oben) gewinnt ebenfalls.
  if (ref.watch(forceFullEffectsProvider)) {
    return safetyCap ? EffectsProfile.reduced : EffectsProfile.full;
  }

  final lite = ref.watch(liteModeActiveProvider);
  final intensity = ref.watch(cinemaIntensityProvider);

  if (lite) {
    return intensity == CinemaIntensity.minimal
        ? EffectsProfile.none
        : EffectsProfile.reduced;
  }
  final base = switch (intensity) {
    CinemaIntensity.full => EffectsProfile.full,
    CinemaIntensity.reduced => EffectsProfile.reduced,
    CinemaIntensity.minimal => EffectsProfile.none,
  };
  // Frame-Watchdog/Memory-Deckel: full -> reduced solange das Gerät strugglet.
  if (base == EffectsProfile.full && safetyCap) {
    return EffectsProfile.reduced;
  }
  return base;
});
