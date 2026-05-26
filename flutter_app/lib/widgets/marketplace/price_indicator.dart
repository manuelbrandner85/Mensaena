/// SKILL: mensaena-features (F76)
/// Vergleicht den Preis eines Listings mit dem Durchschnittspreis der
/// gleichen Kategorie (letzte 90 Tage). Zeigt grünen oder roten Chip.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

final _avgPriceProvider =
    FutureProvider.family.autoDispose<double?, String>((ref, category) async {
  try {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 90))
        .toIso8601String();
    final rows = await sb
        .from('marketplace_listings')
        .select('price')
        .eq('category', category)
        .gte('created_at', since)
        .gt('price', 0);
    if ((rows as List).isEmpty) return null;
    final prices = rows
        .cast<Map<String, dynamic>>()
        .map((r) => (r['price'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (prices.isEmpty) return null;
    return prices.reduce((a, b) => a + b) / prices.length;
  } catch (_) {
    return null;
  }
});

class PriceIndicator extends ConsumerWidget {
  const PriceIndicator({
    required this.price,
    required this.category,
    super.key,
  });

  final double price;
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_avgPriceProvider(category));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (avg) {
        if (avg == null || avg <= 0) return const SizedBox.shrink();
        final isLow = price < avg * 0.85;
        final isHigh = price > avg * 1.15;
        if (!isLow && !isHigh) return const SizedBox.shrink();
        final color = isLow ? AppColors.leben : AppColors.herzrotWarm;
        final txt = isLow
            ? 'community.price_below_avg'
                .tr(namedArgs: {'avg': avg.toStringAsFixed(0)})
            : 'community.price_above_avg'
                .tr(namedArgs: {'avg': avg.toStringAsFixed(0)});
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isLow ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                  size: 11, color: color),
              const SizedBox(width: 4),
              Text(txt,
                  style: AppTypography.body(
                    size: 10,
                    color: color,
                    weight: FontWeight.w700,
                  )),
            ],
          ),
        );
      },
    );
  }
}
