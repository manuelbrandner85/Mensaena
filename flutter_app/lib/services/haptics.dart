/// SKILL: mensaena-design
/// Haptics-Service — zentrale Vibrationssteuerung für UX-Polish.
/// Verwendet HapticFeedback aus Flutter — kein zusätzliches Package.
/// Auto-respektiert System-Setting (kein Override).
library;

import 'package:flutter/services.dart';

class Haptics {
  const Haptics._();

  /// Light-Tap (Card-Tap, Toggle, Chip-Select).
  static void tap() {
    HapticFeedback.lightImpact();
  }

  /// Medium-Tap (Button-Press, Navigation-Switch).
  static void select() {
    HapticFeedback.selectionClick();
  }

  /// Heavy-Tap (Submit, Send, Confirm).
  static void confirm() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy-Heavy (Crisis, Critical-Action, Long-Press).
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Vibrate-Pattern (Notification-Anzeige, Error).
  static void error() {
    HapticFeedback.vibrate();
  }
}
