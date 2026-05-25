/// SKILL: mensaena-features
/// Biometric-Auth via local_auth (F15).
/// Speichert User-Opt-In on-device, frueht Fingerprint/Face-Check
/// beim Cold-Start + nach laengerem Background-Aufenthalt.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  const BiometricService._();

  static const _storage = FlutterSecureStorage();
  static const _enabledKey = 'mensaena_biometric_enabled_v1';
  static const _lastUnlockKey = 'mensaena_biometric_last_unlock_v1';

  /// App muss nach so vielen Sekunden Background neu entsperren.
  static const _relockAfterSec = 180;

  static final LocalAuthentication _auth = LocalAuthentication();

  /// Geraet kann ueberhaupt Biometrie?
  static Future<bool> canAuthenticate() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } catch (e) {
      debugPrint('[Biometric] canAuthenticate failed: $e');
      return false;
    }
  }

  static Future<List<BiometricType>> available() async {
    try {
      return _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> isEnabled() async {
    try {
      return (await _storage.read(key: _enabledKey)) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool v) async {
    try {
      await _storage.write(key: _enabledKey, value: v ? 'true' : 'false');
      if (v) {
        // Bei Activate gleich entsperren — sonst sperrt der Gate sich nach
        // dem ersten Save selbst aus.
        await _markUnlockedNow();
      }
    } catch (_) {}
  }

  /// Triggert den nativen Biometric-Prompt. Liefert true bei Erfolg.
  static Future<bool> authenticate({required String reason}) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (ok) await _markUnlockedNow();
      return ok;
    } catch (e) {
      debugPrint('[Biometric] authenticate failed: $e');
      return false;
    }
  }

  /// True wenn der Gate die App sperren muss.
  /// - Feature deaktiviert → false.
  /// - Letzte Entsperrung < _relockAfterSec sec her → false.
  /// - Sonst → true (= Lock-Screen zeigen).
  static Future<bool> shouldLock() async {
    if (!await isEnabled()) return false;
    try {
      final raw = await _storage.read(key: _lastUnlockKey);
      if (raw == null || raw.isEmpty) return true;
      final ts = int.tryParse(raw);
      if (ts == null) return true;
      final last =
          DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toLocal();
      final delta = DateTime.now().difference(last).inSeconds;
      return delta >= _relockAfterSec;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _markUnlockedNow() async {
    try {
      await _storage.write(
        key: _lastUnlockKey,
        value: '${DateTime.now().toUtc().millisecondsSinceEpoch}',
      );
    } catch (_) {}
  }

  /// Manueller Re-Lock z.B. wenn User in Background geht.
  static Future<void> markBackgrounded() async {
    // Wir muellen den Last-Unlock-Timestamp nicht — nur shouldLock-Logik
    // verarbeitet ihn. Doch wir setzen ihn nicht, damit der Timer laeuft.
  }
}
