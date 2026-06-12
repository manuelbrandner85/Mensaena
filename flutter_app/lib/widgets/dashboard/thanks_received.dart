/// SKILL: mensaena-features
/// ThanksReceived — letzte Trust-Ratings die der User erhalten hat.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/tilt_card.dart';
import '../../repositories/trust_ratings_repository.dart';

class ThanksReceived extends ConsumerWidget {
  const ThanksReceived({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadRatings(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return TiltCard(
          intensity: 0.7,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lebenSoft.withValues(alpha: 0.08),
              border: Border.all(
                  color: AppColors.lebenSoft.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.heart,
                        color: AppColors.lebenSoft, size: 14),
                    const SizedBox(width: 6),
                    Text('home.thanksReceived'.tr(),
                        style: AppTypography.label(
                            size: 10, color: AppColors.lebenSoft)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final r in list.take(2))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var i = 0;
                                i < ((r['stars'] as num?)?.toInt() ?? 0);
                                i++)
                              const Icon(LucideIcons.star,
                                  size: 11, color: AppColors.amber),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (r['comment'] as String?) ?? '—',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                                size: 12,
                                color: AppColors.inkSoft,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadRatings() async {
    try {
      return TrustRatingsRepository.getReceivedFor(userId, limit: 5);
    } catch (_) {
      return const [];
    }
  }
}
