/// SKILL: mensaena-features
/// TrustScoreCard — Trust-Level + Score-Anzeige fuer Dashboard-Home.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/profile.dart';
import '../shared/pressable.dart';

class TrustScoreCard extends StatelessWidget {
  const TrustScoreCard({super.key, required this.profile});
  final Profile profile;

  String _levelLabel(double score) {
    if (score >= 4.5) return 'Legende';
    if (score >= 4.0) return 'Vorbild';
    if (score >= 3.5) return 'Erfahren';
    if (score >= 3.0) return 'Etabliert';
    if (score >= 2.0) return 'Aufsteigend';
    return 'Neu';
  }

  @override
  Widget build(BuildContext context) {
    final score = profile.trustScore.toDouble();
    final count = profile.trustScoreCount;
    final level = _levelLabel(score);
    final ratio = (score / 5).clamp(0.0, 1.0);
    // B1 Mikro-Physik: Karte = Pressable (Spring-Scale + Haptik),
    // InkWell bleibt Listen-Rows vorbehalten.
    return Pressable(
      onTap: () => context.go('/dashboard/profile'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.trust.withValues(alpha: 0.16),
              AppColors.amber.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.trust.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.trust.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.shieldCheck,
                  color: AppColors.trust, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('home.trust'.tr(),
                          style: AppTypography.label(
                              size: 10, color: AppColors.trust)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.trust.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(level,
                            style: AppTypography.label(
                                size: 8, color: AppColors.trustSoft)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(score.toStringAsFixed(1),
                          style: AppTypography.mono(
                            size: 22,
                            color: AppColors.ink,
                          )),
                      Text(' / 5',
                          style: AppTypography.label(
                              size: 10, color: AppColors.mute)),
                      const SizedBox(width: 8),
                      Text('($count Bew.)',
                          style: AppTypography.caption()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 4,
                      backgroundColor: AppColors.elevated,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.trust),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
