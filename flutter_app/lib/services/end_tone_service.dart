/// SKILL: mensaena-features
/// EndToneService — Audio-Feedback beim Beenden eines Anrufs.
///
/// Nutzt SystemSound + Haptics statt eines MP3-Assets, weil:
///   - Kein neues Audio-File ins APK packen (Shorebird-Patch unmoeglich
///     fuer Assets, nur Dart-Code).
///   - Plattform-konsistent (iOS/Android haben native End-Tones im
///     SystemSound-Set).
///   - Keine neue Dependency.
///
/// Pattern wie SoundService.click() — respektiert die User-Praeferenz
/// (sound_enabled_v1) ueber den bestehenden SoundService.
library;

import 'package:flutter/services.dart';

import 'sound_service.dart';

class EndToneService {
  const EndToneService._();

  /// Spielt ein kurzes "Bee-beep" (Click + Click nach 120ms) plus einen
  /// mittelstarken Haptic-Pulse. Idempotent — kann gefahrlos mehrfach
  /// aufgerufen werden.
  static Future<void> play() async {
    final enabled = await SoundService.isEnabled();
    if (!enabled) {
      // Auch ohne Sound: Haptic-Pulse als Bestaetigung.
      HapticFeedback.mediumImpact();
      return;
    }
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      SystemSound.play(SystemSoundType.click);
    });
  }
}
