/// SKILL: mensaena-design (W2 — App-weiter Offline-Hinweis)
/// Schmaler, kollabierender Banner im DashboardScaffold-Kopf: erscheint nur
/// wenn keine Netzwerkverbindung besteht, verschwindet automatisch sobald
/// sie zurückkehrt. Ersetzt stille Ladefehler durch einen klaren Grund.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/connectivity_provider.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: online
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: AppColors.herzrotWarm.withValues(alpha: 0.14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.wifiOff,
                      size: 13, color: AppColors.herzrotWarm),
                  const SizedBox(width: 6),
                  Text('common.offline'.tr(),
                      style: AppTypography.label(
                          size: 11, color: AppColors.herzrotWarm)),
                ],
              ),
            ),
    );
  }
}
