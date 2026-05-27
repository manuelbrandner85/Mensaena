/// SKILL: mensaena-features (Phase 10 B3)
/// Sticky Quick-Actions-Bar — Floating Pill am unteren Dashboard-Rand.
/// Bleibt sichtbar während User scrollt + Sektionen einklappt.
/// Bietet 4 wichtigste Schnellzugriffe: Module-Hub, Map, Chat, Notruf.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/haptics.dart';

class StickyQuickActionsBar extends StatelessWidget {
  const StickyQuickActionsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border:
                Border.all(color: AppColors.bronze.withValues(alpha: 0.45)),
            boxShadow: [
              BoxShadow(
                color: AppColors.voidColor.withValues(alpha: 0.6),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StickyAction(
                icon: LucideIcons.layoutGrid,
                labelKey: 'home.qaModules',
                route: '/dashboard/modules',
                color: AppColors.amber,
              ),
              _StickyAction(
                icon: LucideIcons.map,
                labelKey: 'home.qaMap',
                route: '/dashboard/map',
                color: AppColors.tealSoft,
              ),
              _StickyAction(
                icon: LucideIcons.messageSquare,
                labelKey: 'home.qaChat',
                route: '/dashboard/chat',
                color: AppColors.leben,
              ),
              _StickyAction(
                icon: LucideIcons.alertTriangle,
                labelKey: 'home.qaSos',
                route: '/dashboard/crisis',
                color: AppColors.herzrot,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyAction extends StatelessWidget {
  const _StickyAction({
    required this.icon,
    required this.labelKey,
    required this.route,
    required this.color,
  });
  final IconData icon;
  final String labelKey;
  final String route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Haptics.tap();
        context.push(route);
      },
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              labelKey.tr(),
              style: AppTypography.body(
                size: 10,
                color: color,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
