/// SKILL: mensaena-features
/// QuickActions — 4 prominente Action-Tiles (Post, Map, Chat, SOS).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/bloom.dart';
import '../effects/tilt_card.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  static const _items = <({
    String i18n,
    IconData icon,
    Color accent,
    String route,
  })>[
    // v2.1: 'Neuer Beitrag' raus — Beiträge laufen über Module.
    // qaPost-Eintrag ersetzt durch 'Alle Module' damit User direkt zum
    // Hub springt und dort ein Modul + dessen Create-Flow nimmt.
    (
      i18n: 'home.qaModules',
      icon: LucideIcons.layoutGrid,
      accent: AppColors.amber,
      route: '/dashboard/modules',
    ),
    (
      i18n: 'home.qaMap',
      icon: LucideIcons.map,
      accent: AppColors.teal,
      route: '/dashboard/map',
    ),
    (
      i18n: 'home.qaChat',
      icon: LucideIcons.messageSquare,
      accent: AppColors.leben,
      route: '/dashboard/chat',
    ),
    (
      i18n: 'home.qaSos',
      icon: LucideIcons.alertTriangle,
      accent: AppColors.herzrot,
      route: '/dashboard/crisis',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Premium-2×2-Grid statt horizontalem Scroll: wirkt intentionaler,
    // alle 4 Aktionen sofort sichtbar (keine versteckte Scroll-Discovery).
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: [for (final it in _items) _tile(context, it)],
    );
  }

  Widget _tile(BuildContext context, ({
    String i18n,
    IconData icon,
    Color accent,
    String route,
  }) it) {
    final isSos = it.route == '/dashboard/crisis';
    final tile = InkWell(
      onTap: () => context.go(it.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        // Welten-inspired stronger gradient + breiterer Glow-Schatten in der
        // Akzent-Farbe -- die Kachel "lebt". Innerer Highlight oben (Stack
        // unten) sorgt fuer die typische Glass-Lichtkante.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              it.accent.withValues(alpha: 0.35),
              it.accent.withValues(alpha: 0.10),
              AppColors.surface.withValues(alpha: 0.30),
            ],
            stops: const [0, 0.55, 1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: it.accent.withValues(alpha: isSos ? 0.75 : 0.45),
            width: isSos ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          // Akzent-Glow fuer alle Tiles + extra dunklen Schatten fuer Tiefe.
          // SOS bekommt zusaetzlichen, kraeftigeren Glow (Sicherheits-Signal).
          boxShadow: [
            BoxShadow(
              color: it.accent.withValues(alpha: 0.22),
              blurRadius: 22,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              spreadRadius: -6,
              offset: const Offset(0, 6),
            ),
            if (isSos)
              BoxShadow(
                color: it.accent.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: -2,
              ),
          ],
        ),
        child: Stack(
          children: [
            // Inner highlight strip top -- light catching the glass edge.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: it.accent.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: it.accent.withValues(alpha: 0.30),
                    blurRadius: 12,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Icon(it.icon, size: 19, color: it.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                it.i18n.tr(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 14, color: it.accent.withValues(alpha: 0.7)),
          ],
        ),
          ],
        ),
      ),
    );
    final wrapped = TiltCard(intensity: 0.5, borderRadius: 16, child: tile);
    if (isSos) {
      return Bloom(
        color: AppColors.herzrot,
        intensity: 0.55,
        radius: 22,
        child: wrapped,
      );
    }
    return wrapped;
  }
}
