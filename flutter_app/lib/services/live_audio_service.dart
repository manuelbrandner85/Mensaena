/// SKILL: mensaena-features
/// Punkt 11: Startet/stoppt den nativen Android Foreground-Service
/// (LiveAudioService.kt) damit Livestream-/Call-Audio weiterläuft wenn die
/// App minimiert ist oder der Bildschirm aus geht.
///
/// Alle Aufrufe sind defensiv (try/catch) — ein Fehler beim Service-Start
/// darf NIE den Call/Stream-Einstieg blockieren oder die App crashen.
/// Auf iOS/Web ist der MethodChannel nicht registriert → Aufrufe sind No-Ops.
library;

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class LiveAudioService {
  const LiveAudioService._();

  static const _channel = MethodChannel('de.mensaena.app/audio');

  static bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Foreground-Service starten (beim Room-Connect).
  static Future<void> start() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('start');
    } catch (_) {/* fail-safe: Audio läuft dann nur im Vordergrund */}
  }

  /// Foreground-Service stoppen (beim Verlassen/Auflegen).
  static Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
