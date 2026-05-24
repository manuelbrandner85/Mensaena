/// SKILL: mensaena-design
/// Haptics-Service — zentrale Vibrationssteuerung für UX-Polish.
/// Verwendet HapticFeedback aus Flutter — kein zusätzliches Package.
/// Auto-respektiert System-Setting (kein Override).
///
/// Pattern-Library:
///   - tap()          Card-Tap, Chip, Toggle
///   - select()       Tab-Switch, Picker-Wheel
///   - longPress()    Context-Menu-Trigger, Drag-Start
///   - confirm()      Submit-Button, Send-Button
///   - heavy()        Crisis, Critical-Action
///   - success()      Achievement-Feel (light + light delay)
///   - error()        Form-Error / Rate-Limit (heavy + heavy delay)
///   - notification() Push-Trigger-Look
library;

import 'package:flutter/services.dart';

class Haptics {
  const Haptics._();

  /// Light-Tap (Card-Tap, Toggle, Chip-Select, Bookmark, RSVP).
  static void tap() {
    HapticFeedback.lightImpact();
  }

  /// Selection-Click (Tab-Switch, Picker, Navigation-Switch).
  static void select() {
    HapticFeedback.selectionClick();
  }

  /// Medium-Press (Long-Press, Drag-Start, Context-Menu).
  static void longPress() {
    HapticFeedback.mediumImpact();
  }

  /// Medium-Tap (Submit, Send, Confirm-Action).
  static void confirm() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy-Tap (Crisis, SOS, Critical-Action).
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Heavy-Impact (raw, für SOS-FAB, Notruf).
  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  /// Achievement-Feel: zwei leichte Taps im Abstand von 180ms.
  /// Für erfolgreiche Submits, Save-Confirmations, Helfen-Button.
  static Future<void> success() async {
    HapticFeedback.lightImpact();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    HapticFeedback.lightImpact();
  }

  /// Error-Pattern: zwei heavy Impulse im Abstand von 120ms.
  /// Für Form-Validation-Fehler, Rate-Limit, Permission-Denied.
  static Future<void> error() async {
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
  }

  /// Notification-Trigger (heavy single-shot).
  /// Für Push-In-App-Anzeige, neue Nachricht Hinweis.
  static void notification() {
    HapticFeedback.heavyImpact();
  }

  /// Vibrate-Pattern (Legacy-Alias auf error() für Backwards-Compat).
  @Deprecated('Use Haptics.error() for Error-Pattern oder Haptics.heavy()')
  static void vibrate() {
    HapticFeedback.vibrate();
  }
}
