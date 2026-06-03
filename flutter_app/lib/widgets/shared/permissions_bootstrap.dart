/// SKILL: mensaena-features
/// Einmaliger Permissions-Bootstrap nach dem ersten Login: feuert alle
/// relevanten System-Dialoge in einer einzigen Sequenz ab, damit der Nutzer
/// nur einmal durchklickt und danach nie wieder gefragt wird.
///
/// Wichtig & ehrlich: Android verbietet aus Sicherheitsgründen das stille
/// Erteilen von Runtime-Berechtigungen. Diese Sequenz minimiert die Reibung
/// (alles in einem Rutsch), umgeht das Modell aber NICHT.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import 'battery_optimization_prompt.dart';

const String kPermsBootstrapKey = 'mensaena_perms_bootstrap_v1';

class PermissionsBootstrap extends StatefulWidget {
  const PermissionsBootstrap({super.key});

  @override
  State<PermissionsBootstrap> createState() => _PermissionsBootstrapState();
}

class _PermissionsBootstrapState extends State<PermissionsBootstrap> {
  static const _storage = FlutterSecureStorage();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Lange genug warten, damit Onboarding-Animation / Push-Banner /
    // BatteryOptimizationPrompt nicht gleichzeitig auf den Bildschirm
    // springen. Battery-Prompt feuert nach 12s — wir laufen NACH ihm.
    _timer = Timer(const Duration(seconds: 16), _runOnce);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _runOnce() async {
    if (!mounted) return;
    try {
      final done = await _storage.read(key: kPermsBootstrapKey);
      if (done == 'true') return;
    } catch (_) {
      return;
    }
    // Sofort Flag setzen, damit ein zweiter Start (z. B. Hot-Reload) nicht
    // erneut die ganze Dialog-Salve startet.
    try {
      await _storage.write(key: kPermsBootstrapKey, value: 'true');
    } catch (_) {/* non-fatal */}

    int sdk = 0;
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        sdk = info.version.sdkInt;
      } catch (_) {/* fallback: konservative Liste */}
    }

    // Reihenfolge bewusst: Benachrichtigungen zuerst (auf Android 13+ teilt
    // sich daran der Push-Empfang), dann das, was die meisten Module brauchen.
    final perms = <Permission>[
      Permission.notification,
      Permission.camera,
      Permission.microphone,
      // Android 13+: granulare Medien; älter: pauschal storage.
      if (sdk == 0 || sdk >= 33) ...[
        Permission.photos,
        Permission.audio,
      ] else
        Permission.storage,
      Permission.locationWhenInUse,
      // "Geräte in der Nähe" erst ab Android 12+ überhaupt eine eigene
      // Permission — vorher steckte BT in Standort drin.
      if (sdk == 0 || sdk >= 31) Permission.bluetoothConnect,
      Permission.phone,
    ];

    for (final p in perms) {
      if (!mounted) return;
      try {
        final s = await p.status;
        if (s.isGranted || s.isLimited || s.isPermanentlyDenied) continue;
        await p.request();
      } catch (_) {/* einzelne Permission nicht verfügbar → überspringen */}
    }

    // Akku-Optimierung ist ein eigener System-Dialog (kein simples request);
    // auf Samsung führt der gemeinsame Setup-Flow zusätzlich in die
    // App-Einstellungen für „Apps im Tiefschlaf".
    if (!mounted) return;
    try {
      final batt = await Permission.ignoreBatteryOptimizations.status;
      if (!batt.isGranted) {
        await showBatteryOptimizationSetup(context);
      }
    } catch (_) {/* non-fatal */}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
