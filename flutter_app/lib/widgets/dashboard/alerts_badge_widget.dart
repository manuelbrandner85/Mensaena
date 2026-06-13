/// SKILL: mensaena-features (Phase 10 E9)
/// AlertsBadgeWidget — kompakter "Alles sicher"-Pill solange keine
/// aktiven Warnungen kommen. Sobald NINA-Warnungen, Pegel-Warnungen
/// oder Lebensmittel-Rückrufe aktiv sind → expandiert zu rotem
/// Banner mit Tap-to-Detail.
///
/// Ersetzt das vorherige Mosaik aus SafetyBanners + TrafficInfo +
/// WaterLevel als drei separate Widgets auf dem Dashboard.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import 'safety_banners.dart';

class AlertsBadgeWidget extends ConsumerWidget {
  const AlertsBadgeWidget({this.lat, this.lng, super.key});
  final double? lat;
  final double? lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nina = ref.watch(ninaWarningsProvider((lat: lat, lng: lng)));
    final food = ref.watch(foodWarningsProvider);
    final ninaCount = nina.maybeWhen(data: (l) => l.length, orElse: () => 0);
    final foodCount = food.maybeWhen(data: (l) => l.length, orElse: () => 0);
    final total = ninaCount + foodCount;

    if (total == 0) {
      return _IdlePill();
    }
    // Aktive Warnung → SafetyBanners voll rendern (rot, ggf. pulsierend).
    return SafetyBanners(lat: lat, lng: lng);
  }
}

class _IdlePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.leben.withValues(alpha: 0.12),
        border:
            Border.all(color: AppColors.leben.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(children: [
        const Icon(LucideIcons.shieldCheck,
            size: 14, color: AppColors.leben),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'dashboard.alerts.allClear'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
                size: 12,
                color: AppColors.lebenSoft,
                weight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}
