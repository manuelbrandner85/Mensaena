/// SKILL: mensaena-architektur
/// Device-Tier-Detection — entscheidet bei App-Start, ob das Gerät die
/// vollen UI-Effekte (Cinema-Overlay, Hero-Animationen, Shimmer, Blur)
/// tragen kann oder ob ein „Lite-Mode" aktiviert werden muss.
///
/// Heuristik (Android):
///   - 32-bit ABI (armeabi-v7a oder x86) → IMMER lite
///   - SDK < 28 (Android < 9)            → lite
///   - sonst standard; in Settings auf premium hochsetzbar
///
/// iOS: bleibt standardmäßig "standard" — Apple-Geräte sind tier-weise
/// homogener; Lite kann manuell gesetzt werden.
///
/// Persistenz: einmal ermittelt + cached in flutter_secure_storage. User
/// kann in den Settings überschreiben (Override → bleibt, bis Auto-Reset).
library;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum DeviceTier {
  /// Schwaches/altes Gerät — Effekte aus, kleinere Image-Caches, einfache
  /// Skeletons, keine BackdropFilter/MaskFilter.blur, keine repeat-Anims.
  lite,

  /// Standard-Gerät — alle UI-Features außer den teuersten Cinema-Effekten.
  standard,

  /// Top-Gerät — volles Cinema-Overlay, Hero-Animationen, Shimmer, Blur.
  premium,
}

class DeviceTierInfo {
  const DeviceTierInfo({
    required this.tier,
    required this.is32Bit,
    required this.androidSdk,
    required this.overridden,
  });

  final DeviceTier tier;
  final bool is32Bit;
  final int? androidSdk;
  final bool overridden;
}

class DeviceTierService {
  const DeviceTierService._();

  static const _storage = FlutterSecureStorage();
  static const _overrideKey = 'device_tier_override_v1';

  /// Ermittelt das Geräte-Tier. Lite-Override aus Settings gewinnt.
  static Future<DeviceTierInfo> detect() async {
    final override = await _readOverride();
    final auto = await _autoDetect();
    final effective = override ?? auto.tier;
    return DeviceTierInfo(
      tier: effective,
      is32Bit: auto.is32Bit,
      androidSdk: auto.androidSdk,
      overridden: override != null,
    );
  }

  static Future<_AutoTier> _autoDetect() async {
    if (kIsWeb) {
      return const _AutoTier(
          tier: DeviceTier.standard, is32Bit: false, androidSdk: null);
    }
    try {
      final info = DeviceInfoPlugin();
      // Android: prüfe ABI (32-bit) + SDK-Level.
      if (defaultTargetPlatform == TargetPlatform.android) {
        final a = await info.androidInfo;
        final abis = a.supportedAbis;
        final is32 = abis.isNotEmpty &&
            !abis.any((abi) => abi.contains('64'));
        final sdk = a.version.sdkInt;
        if (is32 || sdk < 28) {
          return _AutoTier(
              tier: DeviceTier.lite, is32Bit: is32, androidSdk: sdk);
        }
        return _AutoTier(
            tier: DeviceTier.standard, is32Bit: false, androidSdk: sdk);
      }
      // iOS: standardmäßig "standard"; ältere iOS-Geräte können manuell
      // auf lite gestellt werden.
      return const _AutoTier(
          tier: DeviceTier.standard, is32Bit: false, androidSdk: null);
    } catch (_) {
      // fail-safe: lieber "standard" als crash. Premium-Effekte sind
      // optional, lite bringt nur perf-Gewinn → kein User-Schaden.
      return const _AutoTier(
          tier: DeviceTier.standard, is32Bit: false, androidSdk: null);
    }
  }

  static Future<DeviceTier?> _readOverride() async {
    try {
      final raw = await _storage.read(key: _overrideKey);
      if (raw == null || raw.isEmpty) return null;
      return DeviceTier.values
          .firstWhere((t) => t.name == raw, orElse: () => DeviceTier.standard);
    } catch (_) {
      return null;
    }
  }

  /// Persistiert ein manuelles Override (Settings).
  static Future<void> setOverride(DeviceTier? tier) async {
    try {
      if (tier == null) {
        await _storage.delete(key: _overrideKey);
      } else {
        await _storage.write(key: _overrideKey, value: tier.name);
      }
    } catch (_) {/* fail-silent */}
  }
}

class _AutoTier {
  const _AutoTier({
    required this.tier,
    required this.is32Bit,
    required this.androidSdk,
  });
  final DeviceTier tier;
  final bool is32Bit;
  final int? androidSdk;
}

/// Globaler Provider — wird einmal beim App-Start geladen. Defaults:
/// `standard`, bis die echte Erkennung durchgelaufen ist (verhindert
/// Flicker beim ersten Frame).
final deviceTierProvider = FutureProvider<DeviceTierInfo>((ref) async {
  return DeviceTierService.detect();
});

/// Synchroner Convenience-Selector. Während die echte Tier-Erkennung
/// lädt, wird "standard" zurückgegeben → keine unnötige Lite-Degradation
/// auf dem ersten Frame.
final effectiveDeviceTierProvider = Provider<DeviceTier>((ref) {
  return ref
          .watch(deviceTierProvider)
          .maybeWhen(data: (info) => info.tier, orElse: () => null) ??
      DeviceTier.standard;
});

/// `true` wenn animierte Effekte (Cinema-Overlay, Shimmer, Hero-Anim,
/// BackdropFilter, MaskFilter.blur, repeat-AnimationControllers) NICHT
/// gerendert werden sollen.
final liteModeActiveProvider = Provider<bool>((ref) {
  return ref.watch(effectiveDeviceTierProvider) == DeviceTier.lite;
});
