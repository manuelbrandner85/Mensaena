/// SKILL: mensaena-features + mensaena-design
/// Affirmation-Widget (F47): rotierende Tages-Affirmation aus i18n-Pool.
/// Anders als das ZenQuotes-Widget (F28) sind das native, ruhige
/// Mensaena-spezifische Saetze ohne API.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';

class AffirmationWidget extends StatelessWidget {
  const AffirmationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Day-of-year als Index in den Pool (7 Eintraege → wiederholt sich nach 7 Tagen).
    final now = DateTime.now();
    final dayOfYear =
        now.difference(DateTime(now.year)).inDays;
    final idx = (dayOfYear % 7) + 1;
    final text = 'affirmation.pool.$idx'.tr();
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Bloom(
                color: AppColors.tealSoft,
                intensity: 0.45,
                radius: 8,
                child: Icon(LucideIcons.sparkles,
                    size: 16, color: AppColors.tealSoft),
              ),
              const SizedBox(width: 8),
              Text('affirmation.title'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '„$text"',
            style: GoogleFonts.fraunces(
              fontStyle: FontStyle.italic,
              fontSize: 15,
              height: 1.55,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
