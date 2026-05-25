/// SKILL: mensaena-features + mensaena-design
/// TrafficInfoWidget — Top-5 Verkehrsmeldungen DE.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/traffic_service.dart';
import '../effects/glass_card.dart';

final _trafficProvider = FutureProvider<List<TrafficWarning>>((ref) async {
  return TrafficService.top(limit: 5);
});

class TrafficInfoWidget extends ConsumerWidget {
  const TrafficInfoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_trafficProvider);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertOctagon,
                  size: 16, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                'traffic.title'.tr(),
                style: AppTypography.body(
                    size: 13,
                    color: AppColors.ink,
                    weight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'common.refresh'.tr(),
                splashRadius: 16,
                iconSize: 14,
                onPressed: () => ref.invalidate(_trafficProvider),
                icon: const Icon(LucideIcons.refreshCw,
                    color: AppColors.mute),
              ),
            ],
          ),
          const SizedBox(height: 8),
          async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.amber),
                ),
              ),
            ),
            error: (_, __) => Text(
              'traffic.error'.tr(),
              style: AppTypography.caption(),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'traffic.empty'.tr(),
                  style: AppTypography.body(
                      size: 12, color: AppColors.mute),
                );
              }
              return Column(
                children: [
                  for (final w in list) _TrafficRow(w: w),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrafficRow extends StatelessWidget {
  const _TrafficRow({required this.w});
  final TrafficWarning w;

  @override
  Widget build(BuildContext context) {
    final accent =
        w.isBlocked ? AppColors.herzrot : AppColors.amber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              border: Border.all(color: accent),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              w.road,
              style: AppTypography.mono(
                size: 10,
                color: accent,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                      size: 12,
                      color: AppColors.ink,
                      weight: FontWeight.w600),
                ),
                if (w.subtitle.isNotEmpty)
                  Text(
                    w.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                        size: 11, color: AppColors.inkSoft),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
