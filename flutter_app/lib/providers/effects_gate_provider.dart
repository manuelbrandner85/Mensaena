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

final effectsProfileProvider = Provider<EffectsProfile>((ref) {
  // effectiveReduceMotion: schließt seniorMode mit ein.
  final reduceMotion = ref.watch(a11yProvider).effectiveReduceMotion;
  if (reduceMotion) return EffectsProfile.none;

  // User-Override „Maximale Kino-Effekte": volle Effekte trotz Lite-Tier
  // und Watchdog-Deckel (A11y oben gewinnt aber weiterhin).
  if (ref.watch(forceFullEffectsProvider)) return EffectsProfile.full;

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
  // Frame-Watchdog-Deckel: full -> reduced solange das Gerät janked.
  if (base == EffectsProfile.full &&
      ref.watch(runtimeEffectsCapProvider)) {
    return EffectsProfile.reduced;
  }
  return base;
});
