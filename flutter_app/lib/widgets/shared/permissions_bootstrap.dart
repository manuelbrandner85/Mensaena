/// SKILL: mensaena-features
/// Einmaliger Permissions-Bootstrap nach dem ersten Login: feuert alle
/// relevanten System-Dialoge in einer einzigen Sequenz ab — vor jedem
/// System-Dialog erscheint ein eigenes Rationale-Sheet, das den Nutzwert
/// erklärt, damit die User mit hoher Wahrscheinlichkeit "Erlauben" tippt.
///
/// Wichtig & ehrlich: Android verbietet aus Sicherheitsgründen das stille
/// Erteilen von Runtime-Berechtigungen. Wir minimieren die Reibung maximal
/// (Vorerklärung + alle Dialoge in einem Rutsch), umgehen das Modell aber NICHT.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import 'battery_optimization_prompt.dart';
import 'permission_rationale_sheet.dart';

// v2: zusammen mit den nutzwertfokussierten Rationale-Sheets neu ausspielen,
// damit Bestandsnutzer die verbesserte Erklär-Sequenz einmalig sehen.
const String kPermsBootstrapKey = 'mensaena_perms_bootstrap_v2';

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

  /// Map einer Android-Permission auf den Rationale-Schlüssel, dessen Sheet
  /// vor dem System-Dialog gezeigt wird. Reihenfolge zählt — Notifications
  /// zuerst (Android 13+ teilt sich daran der Push-Empfang), Phone zuletzt.
  Future<List<({Permission perm, PermissionRationaleKey rationale})>>
      _plan() async {
    int sdk = 0;
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        sdk = info.version.sdkInt;
      } catch (_) {/* Default 0 → konservative Liste */}
    }
    final list =
        <({Permission perm, PermissionRationaleKey rationale})>[
      (perm: Permission.notification, rationale: PermissionRationaleKey.notification),
      (perm: Permission.camera, rationale: PermissionRationaleKey.camera),
      (perm: Permission.microphone, rationale: PermissionRationaleKey.microphone),
    ];
    if (sdk == 0 || sdk >= 33) {
      list
        ..add((perm: Permission.photos, rationale: PermissionRationaleKey.photos))
        ..add((perm: Permission.audio, rationale: PermissionRationaleKey.audio));
    } else {
      list.add((perm: Permission.storage, rationale: PermissionRationaleKey.photos));
    }
    list.add((perm: Permission.locationWhenInUse, rationale: PermissionRationaleKey.location));
    if (sdk == 0 || sdk >= 31) {
      list.add((perm: Permission.bluetoothConnect, rationale: PermissionRationaleKey.nearby));
    }
    list.add((perm: Permission.phone, rationale: PermissionRationaleKey.phone));
    return list;
  }

  Future<void> _runOnce() async {
    if (!mounted) return;
    try {
      final done = await _storage.read(key: kPermsBootstrapKey);
      if (done == 'true') return;
    } catch (_) {
      return;
    }
    // Sofort Flag setzen, damit Hot-Reload / Doppel-Mount nicht erneut
    // die ganze Dialog-Salve startet.
    try {
      await _storage.write(key: kPermsBootstrapKey, value: 'true');
    } catch (_) {/* non-fatal */}

    // Intro: erklärt den User in einem Satz, was gleich passiert — danach
    // weiß er, dass die Sequenz absichtlich ist und tippt durch.
    if (!mounted) return;
    final go = await _showIntro(context);
    if (!go || !mounted) return;

    final plan = await _plan();
    for (final step in plan) {
      if (!mounted) return;
      try {
        final s = await step.perm.status;
        // Bereits erteilt oder vom User dauerhaft abgelehnt → still überspringen.
        if (s.isGranted || s.isLimited || s.isPermanentlyDenied) continue;
      } catch (_) {/* Permission unbekannt → überspringen */
        continue;
      }
      if (!mounted) return;
      final cont = await showPermissionRationale(context, step.rationale);
      if (!mounted) return;
      if (!cont) continue;
      try {
        await step.perm.request();
      } catch (_) {/* Plattform-Edgecase still ignorieren */}
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

  Future<bool> _showIntro(BuildContext context) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.bronze.withValues(alpha: 0.34),
                    AppColors.bronze.withValues(alpha: 0.08),
                  ]),
                ),
                child: const Icon(LucideIcons.shieldCheck,
                    color: AppColors.bronze, size: 26),
              ),
              const SizedBox(height: 18),
              Text(
                'permissions.title'.tr(),
                style: AppTypography.display(size: 19, color: AppColors.ink),
              ),
              const SizedBox(height: 10),
              Text(
                'permissions.rationales.intro'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.body(
                    size: 13.5, color: AppColors.inkSoft, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(LucideIcons.arrowRight, size: 16),
                  label: Text(
                    'permissions.rationales.continue'.tr(),
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.voidColor,
                      weight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'permissions.rationales.later'.tr(),
                  style: AppTypography.body(size: 13, color: AppColors.mute),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
