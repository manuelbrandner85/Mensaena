/// SKILL: mensaena-features + mensaena-design
/// Moon-Widget (F60): heutige Mondphase + Beleuchtungs-%.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/moon_service.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';

class MoonWidget extends StatelessWidget {
  const MoonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final info = MoonService.now();
    final illPct = (info.illumination * 100).round();
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Bloom(
            color: AppColors.tealSoft,
            intensity: 0.5,
            radius: 14,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tealSoft.withValues(alpha: 0.14),
                border: Border.all(
                    color: AppColors.tealSoft.withValues(alpha: 0.5)),
              ),
              child: Text(info.emoji,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.moon,
                        size: 14, color: AppColors.tealSoft),
                    const SizedBox(width: 6),
                    Text('moon.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(info.labelKey.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.inkSoft)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$illPct%',
                  style: AppTypography.display(
                      size: 20, color: AppColors.tealSoft)),
              Text('moon.illumination'.tr(),
                  style: AppTypography.caption()),
            ],
          ),
        ],
      ),
    );
  }
}
