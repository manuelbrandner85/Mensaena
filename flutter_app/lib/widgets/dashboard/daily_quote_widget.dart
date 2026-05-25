/// SKILL: mensaena-features + mensaena-design
/// Zitat des Tages — ZenQuotes, Fraunces-kursiv, Share-Button.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/quote_service.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';

final _quoteProvider = FutureProvider<Quote?>((ref) async {
  return QuoteService.fetchDaily();
});

class DailyQuoteWidget extends ConsumerWidget {
  const DailyQuoteWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_quoteProvider);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Bloom(
                color: AppColors.amber,
                intensity: 0.4,
                radius: 8,
                child: Icon(LucideIcons.quote,
                    size: 16, color: AppColors.amber),
              ),
              const SizedBox(width: 8),
              Text('quote.title'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
              const Spacer(),
              Text('ZenQuotes', style: AppTypography.caption()),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.amber),
                ),
              ),
            ),
            error: (_, __) => Text('quote.error'.tr(),
                style: AppTypography.caption()),
            data: (q) {
              if (q == null) {
                return Text('quote.empty'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.mute));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '„${q.text}"',
                    style: GoogleFonts.fraunces(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: AppColors.ink,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('— ${q.author}',
                          style: AppTypography.body(
                              size: 12,
                              color: AppColors.inkSoft,
                              weight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'quote.share'.tr(),
                        splashRadius: 16,
                        onPressed: () => Share.share(
                            '„${q.text}"\n— ${q.author}\n\n— Mensaena'),
                        icon: const Icon(LucideIcons.share2,
                            size: 14, color: AppColors.bronze),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
