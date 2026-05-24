/// SKILL: mensaena-features
/// AudioFeedbackService (V6) — central singleton for short UI sound effects.
///
/// Plays bundled MP3 assets from `assets/sounds/` via the `audioplayers`
/// package. Asset files are intentionally not committed yet — they will be
/// shipped via Shorebird patch in a follow-up. Every play call is wrapped in
/// try/catch so MissingPluginException / AssetNotFoundException is silently
/// swallowed and never crashes the UI.
///
/// User preference (sound on/off) is persisted in `flutter_secure_storage`
/// under the key `mensaena_notify_sound` (default: ON).
///
/// Call-ring is played as a looping stream until [stopCallRing] is invoked.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure-storage key for the global notification-sound toggle.
const String kSoundEnabledKey = 'mensaena_notify_sound';

class AudioFeedbackService {
  AudioFeedbackService._();

  /// Singleton accessor. All callers share the same player instances so the
  /// looping call-ring can be stopped from anywhere.
  static final AudioFeedbackService instance = AudioFeedbackService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Dedicated player for the looping incoming-call ring — kept separate so
  /// other one-shot sounds don't cancel it.
  final AudioPlayer _ringPlayer = AudioPlayer();

  /// Pool of one-shot players. We create a fresh AudioPlayer per call so
  /// overlapping notifications don't truncate each other.
  bool _enabledCached = true;
  bool _enabledLoaded = false;

  /// Returns the user's "notification sound" preference. Defaults to true
  /// when the key is missing or storage read fails.
  Future<bool> isSoundEnabled() async {
    if (_enabledLoaded) return _enabledCached;
    try {
      final raw = await _storage.read(key: kSoundEnabledKey);
      _enabledCached = raw == null ? true : raw != 'false';
    } catch (_) {
      _enabledCached = true;
    }
    _enabledLoaded = true;
    return _enabledCached;
  }

  /// Persist the user preference. Subsequent [isSoundEnabled] calls use the
  /// cached value without re-reading storage.
  Future<void> setSoundEnabled(bool value) async {
    _enabledCached = value;
    _enabledLoaded = true;
    try {
      await _storage.write(
        key: kSoundEnabledKey,
        value: value ? 'true' : 'false',
      );
    } catch (_) {/* non-fatal */}
  }

  /// Plays a single asset and disposes the player when finished. Safe to
  /// call when assets are missing — swallows all errors.
  Future<void> _playOnce(String assetPath) async {
    if (!await isSoundEnabled()) return;
    final player = AudioPlayer();
    try {
      await player.play(AssetSource(assetPath));
      // Auto-dispose after playback ends so we don't leak players.
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint('AudioFeedbackService: asset "$assetPath" failed: $e');
      try {
        await player.dispose();
      } catch (_) {/* ignore */}
    }
  }

  /// Short "ding" — used for new chat messages / push notifications.
  Future<void> playNotification() => _playOnce('sounds/notification.mp3');

  /// Warm welcome melody — played once on cold-start splash.
  Future<void> playStartupMelody() => _playOnce('sounds/startup.mp3');

  /// Confirmation chime — used for completed actions (post created, etc).
  Future<void> playSuccess() => _playOnce('sounds/success.mp3');

  /// Soft error tone — used for failed validations / network errors.
  Future<void> playError() => _playOnce('sounds/error.mp3');

  /// Starts the looping call-ring. Idempotent — repeated calls do not stack.
  Future<void> playCallRing() async {
    if (!await isSoundEnabled()) return;
    try {
      await _ringPlayer.stop();
      await _ringPlayer.setReleaseMode(ReleaseMode.loop);
      await _ringPlayer.play(AssetSource('sounds/ring.mp3'));
    } catch (e) {
      debugPrint('AudioFeedbackService: call-ring failed: $e');
    }
  }

  /// Stops the looping call-ring. Safe to call when nothing is playing.
  Future<void> stopCallRing() async {
    try {
      await _ringPlayer.stop();
    } catch (_) {/* ignore */}
  }

  /// Releases native audio resources. Call from app shutdown / tests.
  Future<void> dispose() async {
    try {
      await _ringPlayer.dispose();
    } catch (_) {/* ignore */}
  }
}
