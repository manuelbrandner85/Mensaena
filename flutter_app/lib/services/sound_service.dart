/// SKILL: mensaena-design
/// SoundService — dezente UI-Sounds via SystemSound (kein Asset nötig).
/// Persistierte User-Präferenz: an/aus.
/// Kombinierbar mit Haptics für Multi-Sensory-Feedback.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'haptics.dart';

const _soundEnabledKey = 'sound_enabled_v1';
const _storage = FlutterSecureStorage();

class SoundService {
  const SoundService._();

  static bool _enabled = true;
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read(key: _soundEnabledKey);
      _enabled = raw != 'false';
    } catch (_) {/* default true */}
    _loaded = true;
  }

  static Future<bool> isEnabled() async {
    await _ensureLoaded();
    return _enabled;
  }

  static Future<void> setEnabled(bool v) async {
    _enabled = v;
    _loaded = true;
    try {
      await _storage.write(key: _soundEnabledKey, value: v ? 'true' : 'false');
    } catch (_) {}
  }

  /// Plays a soft click sound (tap, toggle).
  static Future<void> click() async {
    await _ensureLoaded();
    if (!_enabled) return;
    SystemSound.play(SystemSoundType.click);
  }

  /// Plays an alert sound (notification, incoming).
  static Future<void> alert() async {
    await _ensureLoaded();
    if (!_enabled) return;
    SystemSound.play(SystemSoundType.alert);
  }

  /// Click + haptic combined (recommended for buttons).
  static Future<void> tap() async {
    Haptics.tap();
    await click();
  }

  /// Confirm + haptic combined (recommended for submit).
  static Future<void> confirm() async {
    Haptics.confirm();
    await click();
  }
}

final soundEnabledProvider = FutureProvider<bool>((ref) async {
  return SoundService.isEnabled();
});
