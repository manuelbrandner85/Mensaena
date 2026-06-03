/// SKILL: mensaena-features
/// Gate-Service: persistente Attempt-Zähler pro Berechtigung + Catalog der
/// Items, die der Permissions-Gate-Screen abfragt. Max. 3 Versuche pro
/// Berechtigung — danach gilt sie als "nur via Einstellungen erteilbar"
/// und blockiert den Gate nicht mehr.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/shared/permission_rationale_sheet.dart';

const int kPermissionsGateMaxAttempts = 3;
const String _kAttemptsStorageKey = 'mensaena_perms_gate_attempts_v1';
const String _kHintShownPrefix = 'mensaena_perms_gate_hint_shown_';
const FlutterSecureStorage _storage = FlutterSecureStorage();

/// Beschreibt einen Gate-Eintrag. customStatus/customAction überschreiben
/// das Standardverhalten (`permission.status` / `permission.request()`).
class GateItem {
  const GateItem({
    required this.key,
    required this.labelKey,
    required this.descKey,
    required this.icon,
    required this.rationale,
    this.permission,
    this.customStatus,
    this.customAction,
  });

  /// Stabiler Identifier — wird auch als Schlüssel im Attempts-Speicher
  /// genutzt. Nicht ändern, sonst startet die Zählung wieder bei 0.
  final String key;
  final String labelKey;
  final String descKey;
  final IconData icon;
  final PermissionRationaleKey rationale;
  final Permission? permission;
  final Future<PermissionStatus> Function()? customStatus;
  // Liefert true, wenn die Aktion wirklich angefragt hat (für Attempt-Zähler).
  final Future<bool> Function()? customAction;
}

/// Aktueller Status eines Gate-Eintrags inkl. attemptCount und ob er den
/// Gate noch blockiert (= weder erteilt noch ausgeschöpft).
class GateState {
  const GateState({
    required this.item,
    required this.status,
    required this.attempts,
  });

  final GateItem item;
  final PermissionStatus status;
  final int attempts;

  bool get isGranted => status.isGranted || status.isLimited;
  bool get isExhausted => attempts >= kPermissionsGateMaxAttempts && !isGranted;

  /// Blockt das "Fertig"-Button: nicht erteilt UND noch nicht aufgebraucht.
  bool get blocksGate => !isGranted && !isExhausted;
}

class PermissionsGate {
  PermissionsGate._();

  /// Gibt den Katalog der zu fragenden Berechtigungen zurück, abhängig von
  /// Android-Version (z. B. Media-Perms erst ab SDK 33, Nearby ab 31).
  static Future<List<GateItem>> catalog() async {
    int sdk = 0;
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        sdk = info.version.sdkInt;
      } catch (_) {/* konservativer Default */}
    }
    final useMediaPerms = sdk == 0 || sdk >= 33;
    return <GateItem>[
      const GateItem(
        key: 'notification',
        labelKey: 'permissions.items.notifications',
        descKey: 'permissions.items.notificationsDesc',
        icon: LucideIcons.bell,
        rationale: PermissionRationaleKey.notification,
        permission: Permission.notification,
      ),
      const GateItem(
        key: 'microphone',
        labelKey: 'permissions.items.microphone',
        descKey: 'permissions.items.microphoneDesc',
        icon: LucideIcons.mic,
        rationale: PermissionRationaleKey.microphone,
        permission: Permission.microphone,
      ),
      const GateItem(
        key: 'camera',
        labelKey: 'permissions.items.camera',
        descKey: 'permissions.items.cameraDesc',
        icon: LucideIcons.camera,
        rationale: PermissionRationaleKey.camera,
        permission: Permission.camera,
      ),
      const GateItem(
        key: 'location',
        labelKey: 'permissions.items.location',
        descKey: 'permissions.items.locationDesc',
        icon: LucideIcons.mapPin,
        rationale: PermissionRationaleKey.location,
        permission: Permission.locationWhenInUse,
      ),
      // Photos-Eintrag ist NICHT const, weil `permission` über einen
      // Runtime-Ternary aus useMediaPerms gesetzt wird.
      GateItem(
        key: 'photos',
        labelKey: 'permissions.items.photos',
        descKey: 'permissions.items.photosDesc',
        icon: LucideIcons.image,
        rationale: PermissionRationaleKey.photos,
        permission: useMediaPerms ? Permission.photos : Permission.storage,
      ),
      if (useMediaPerms)
        const GateItem(
          key: 'audio',
          labelKey: 'permissions.items.audioFiles',
          descKey: 'permissions.items.audioFilesDesc',
          icon: LucideIcons.music,
          rationale: PermissionRationaleKey.audio,
          permission: Permission.audio,
        ),
      const GateItem(
        key: 'phone',
        labelKey: 'permissions.items.phone',
        descKey: 'permissions.items.phoneDesc',
        icon: LucideIcons.phoneCall,
        rationale: PermissionRationaleKey.phone,
        permission: Permission.phone,
      ),
      if (sdk == 0 || sdk >= 31)
        const GateItem(
          key: 'nearby',
          labelKey: 'permissions.items.nearby',
          descKey: 'permissions.items.nearbyDesc',
          icon: LucideIcons.bluetooth,
          rationale: PermissionRationaleKey.nearby,
          permission: Permission.bluetoothConnect,
        ),
      // Fullscreen-Intent hat kein Permission.X-Enum.
      GateItem(
        key: 'fullscreenCall',
        labelKey: 'permissions.items.fullscreenCall',
        descKey: 'permissions.items.fullscreenCallDesc',
        icon: LucideIcons.maximize2,
        rationale: PermissionRationaleKey.fullscreenCall,
        customStatus: () async {
          try {
            final ok =
                await FlutterCallkitIncoming.canUseFullScreenIntent();
            return ok == true
                ? PermissionStatus.granted
                : PermissionStatus.denied;
          } catch (_) {
            return PermissionStatus.denied;
          }
        },
        customAction: () async {
          try {
            await FlutterCallkitIncoming.requestFullIntentPermission();
            return true;
          } catch (_) {
            return false;
          }
        },
      ),
      // SYSTEM_ALERT_WINDOW (Samsung-Vollbild-Anruf).
      const GateItem(
        key: 'overlay',
        labelKey: 'permissions.items.overlay',
        descKey: 'permissions.items.overlayDesc',
        icon: LucideIcons.layers,
        rationale: PermissionRationaleKey.overlay,
        permission: Permission.systemAlertWindow,
      ),
    ];
  }

  // ───────────────────────── Attempt-Persistenz ─────────────────────────

  static Future<Map<String, int>> _readAttempts() async {
    try {
      final raw = await _storage.read(key: _kAttemptsStorageKey);
      if (raw == null || raw.isEmpty) return <String, int>{};
      final m = jsonDecode(raw);
      if (m is Map) {
        return m.map((k, v) => MapEntry('$k', (v as num).toInt()));
      }
    } catch (e) {
      debugPrint('[PermissionsGate] readAttempts failed: $e');
    }
    return <String, int>{};
  }

  static Future<void> _writeAttempts(Map<String, int> m) async {
    try {
      await _storage.write(
          key: _kAttemptsStorageKey, value: jsonEncode(m));
    } catch (_) {/* non-fatal */}
  }

  /// Erhöht den Versuchszähler für [itemKey] um 1.
  static Future<void> recordAttempt(String itemKey) async {
    final m = await _readAttempts();
    m[itemKey] = (m[itemKey] ?? 0) + 1;
    await _writeAttempts(m);
  }

  /// Setzt den Zähler explizit zurück (z. B. nach Logout).
  static Future<void> resetAttempts() async {
    try {
      await _storage.delete(key: _kAttemptsStorageKey);
    } catch (_) {/* non-fatal */}
  }

  // ─────────────────────────── State-Berechnung ──────────────────────────

  /// Liest den aktuellen Status aller Einträge inkl. Attempts.
  static Future<List<GateState>> currentStates() async {
    final items = await catalog();
    final attempts = await _readAttempts();
    final out = <GateState>[];
    for (final it in items) {
      PermissionStatus s;
      try {
        s = it.customStatus != null
            ? await it.customStatus!()
            : await (it.permission ?? Permission.notification).status;
      } catch (_) {
        s = PermissionStatus.denied;
      }
      out.add(GateState(
        item: it,
        status: s,
        attempts: attempts[it.key] ?? 0,
      ));
    }
    return out;
  }

  /// Soll der Vollbild-Gate angezeigt werden?
  /// True, wenn mindestens ein Item den Gate noch blockiert (nicht erteilt
  /// UND Attempts < 3).
  static Future<bool> shouldShowGate() async {
    final states = await currentStates();
    return states.any((s) => s.blocksGate);
  }

  /// True, wenn der Gate nicht mehr nötig ist, aber noch Items existieren,
  /// die nur über Einstellungen erteilt werden können → Hinweis-Snackbar.
  static Future<bool> shouldShowSettingsHint(String sessionId) async {
    final states = await currentStates();
    final anyExhaustedMissing = states.any((s) => s.isExhausted);
    final anyBlocks = states.any((s) => s.blocksGate);
    if (anyBlocks || !anyExhaustedMissing) return false;
    // Pro Session nur einmal zeigen (nicht beim Wechsel zwischen Tabs).
    final flagKey = '$_kHintShownPrefix$sessionId';
    try {
      final shown = await _storage.read(key: flagKey);
      if (shown == 'true') return false;
      await _storage.write(key: flagKey, value: 'true');
    } catch (_) {/* non-fatal */}
    return true;
  }
}
