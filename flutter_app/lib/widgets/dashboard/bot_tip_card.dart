/// SKILL: mensaena-features
/// BotTipCard — Taeglich rotierende Mensaena-Bot-Tipps.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/tilt_card.dart';

class BotTipCard extends StatefulWidget {
  const BotTipCard({super.key});

  @override
  State<BotTipCard> createState() => _BotTipCardState();
}

class _BotTipCardState extends State<BotTipCard> {
  static const _tips = <String>[
    'Hast du heute schon die Karte gecheckt? Vielleicht braucht jemand in deiner Nähe Hilfe!',
    'Ein Lächeln kostet nichts – schreib deinem Nachbarn eine nette Nachricht.',
    'Teile deine Fähigkeiten! Im Skill-Netzwerk kannst du anderen helfen und Neues lernen.',
    'Kleine Gesten, große Wirkung: Biete Einkaufshilfe in deiner Nachbarschaft an.',
    'Kennst du die Zeitbank? Tausche Zeit statt Geld mit deinen Nachbarn!',
  ];
  late String _current;

  @override
  void initState() {
    super.initState();
    _current = _tips[DateTime.now().day % _tips.length];
  }

  void _next() {
    setState(() {
      final idx = (_tips.indexOf(_current) + 1) % _tips.length;
      _current = _tips[idx];
    });
  }

  @override
  Widget build(BuildContext context) {
    return TiltCard(
      intensity: 0.7,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.bronze.withValues(alpha: 0.12),
              AppColors.amber.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.bronze.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bronze.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.sparkles,
                      size: 14, color: AppColors.bronze),
                ),
                const SizedBox(width: 8),
                Text('home.botName'.tr(),
                    style: AppTypography.body(
                        size: 12,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
                const Spacer(),
                const Icon(LucideIcons.lightbulb,
                    size: 14, color: AppColors.bronze),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _current,
              style: AppTypography.body(
                  size: 13, color: AppColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: () => context.go('/dashboard/chat'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 24),
                  ),
                  child: Text('home.chatWithBot'.tr(),
                      style: AppTypography.label(
                          size: 9, color: AppColors.bronze)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _next,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 24),
                  ),
                  icon: const Icon(LucideIcons.refreshCw,
                      size: 11, color: AppColors.bronze),
                  label: Text('home.nextTip'.tr(),
                      style: AppTypography.label(
                          size: 9, color: AppColors.bronze)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
