/// SKILL: mensaena-features
/// Einmaliger, dezenter Hinweis-Dialog zur Akku-Optimierung.
///
/// Hintergrund: Auf aggressiven Android-OEMs (Xiaomi/MIUI, Huawei/EMUI,
/// Samsung, Oppo …) wird die App im Killed-State trotz FCM-HIGH-Priority
/// in den Doze-Schlaf gezwungen → eingehende Anrufe/Push kommen verspätet
/// oder gar nicht. Das lässt sich NICHT per Code erzwingen — der Nutzer
/// muss die App einmalig von der Akku-Optimierung ausnehmen.
///
/// Verhalten:
///   • nur Android, nur einmal (Flag in SecureStorage),
///   • erst nach kurzer Warm-up-Phase, und nur wenn die Ausnahme noch NICHT
///     erteilt ist,
///   • CTA ruft die System-Abfrage auf (Direktlink); "Später" verwirft.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

const String kBatteryPromptShownKey = 'mensaena_battery_prompt_shown_v1';

class BatteryOptimizationPrompt extends StatefulWidget {
  const BatteryOptimizationPrompt({super.key});

  @override
  State<BatteryOptimizationPrompt> createState() =>
      _BatteryOptimizationPromptState();
}

class _BatteryOptimizationPromptState extends State<BatteryOptimizationPrompt> {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Erst NACH dem Push-Permission-Banner (das nach 5s slidet), damit sich
    // nicht beides gleichzeitig meldet.
    _timer = Timer(const Duration(seconds: 12), _evaluate);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _evaluate() async {
    if (!mounted || !Platform.isAndroid) return;
    try {
      final shown = await _storage.read(key: kBatteryPromptShownKey);
      if (shown == 'true') return;
      // Schon ausgenommen? Dann gar nicht fragen.
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) {
        await _markShown();
        return;
      }
      if (!mounted) return;
      await _showDialog();
    } catch (_) {
      // permission_handler nicht verfügbar / API fehlt → still ignorieren.
    }
  }

  Future<void> _markShown() async {
    try {
      await _storage.write(key: kBatteryPromptShownKey, value: 'true');
    } catch (_) {/* non-fatal */}
  }

  Future<void> _showDialog() async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: const Icon(LucideIcons.batteryCharging,
            size: 28, color: AppColors.amber),
        title: Text('battery.title'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        content: Text('battery.body'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.body(
                size: 13, color: AppColors.inkSoft, height: 1.45)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'later'),
            child: Text('battery.later'.tr(),
                style: AppTypography.body(size: 13, color: AppColors.mute)),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'allow'),
            icon: const Icon(LucideIcons.shieldCheck, size: 16),
            label: Text('battery.allow'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.voidColor,
            ),
          ),
        ],
      ),
    );
    // Egal wie entschieden — nur einmal fragen.
    await _markShown();
    if (action == 'allow') {
      try {
        final res = await Permission.ignoreBatteryOptimizations.request();
        // Falls das System-Dialog nicht erscheint (manche OEMs) → direkt in
        // die App-Einstellungen, wo der Nutzer es manuell setzen kann.
        if (!res.isGranted) {
          await openAppSettings();
        }
      } catch (_) {/* non-fatal */}
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
