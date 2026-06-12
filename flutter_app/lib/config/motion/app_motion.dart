/// SKILL: mensaena-design (Premium-Motion / Phase-5-Fundament)
/// AppMotion — physikbasierte Motion-Tokens, analog zu AppColors.
///
/// Bewusst OHNE neues Package (flutter_animate & Co. hießen pubspec-
/// Änderung = Version-Bump statt OTA): SpringDescription/SpringSimulation
/// sind Flutter-SDK. Drei benannte Federn decken die App ab:
///
///   snappy  — Buttons, Toggles, Chips (schnell, kaum Überschwingen)
///   gentle  — Sheets, Cards, Page-Elemente (weich, kein Bounce)
///   bouncy  — Celebrations, Badges, Confetti-Momente (sichtbarer Bounce)
///
/// Verwendung:
///   controller.springTo(1.0, spring: AppMotion.snappy);
///   controller.springTo(0.0, spring: AppMotion.gentle,
///       velocity: dragVelocity);   // Momentum aus Geste übernehmen
///
/// Keine Ad-hoc-Kurven mehr in Screens — wer eine vierte Feder braucht,
/// ergänzt sie HIER mit Begründung.
library;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

class AppMotion {
  const AppMotion._();

  /// Buttons/Toggles: erreicht das Ziel in ~250 ms, minimaler Overshoot.
  static const SpringDescription snappy =
      SpringDescription(mass: 1, stiffness: 500, damping: 30);

  /// Sheets/Cards: weiches Einschwingen ohne Bounce (~400 ms).
  static const SpringDescription gentle =
      SpringDescription(mass: 1, stiffness: 250, damping: 28);

  /// Celebrations: deutlicher, lebendiger Bounce (~600 ms).
  static const SpringDescription bouncy =
      SpringDescription(mass: 1, stiffness: 320, damping: 14);

  /// Fertige Simulation, z. B. für Draggable-Dismiss mit Fling-Velocity.
  static SpringSimulation simulation(
    SpringDescription spring, {
    required double from,
    required double to,
    double velocity = 0,
  }) =>
      SpringSimulation(spring, from, to, velocity);
}

extension SpringAnimate on AnimationController {
  /// Animiert physikbasiert zum Ziel. [velocity] in value-Einheiten/s —
  /// bei Drag-Gesten: pixelVelocity / Distanz übergeben, dann fühlt sich
  /// der Übergang wie eine Fortsetzung der Geste an (Momentum).
  TickerFuture springTo(
    double target, {
    SpringDescription spring = AppMotion.gentle,
    double velocity = 0,
  }) {
    return animateWith(
      AppMotion.simulation(spring, from: value, to: target, velocity: velocity),
    );
  }
}
