/// WaterLevelWidget V2 — Provider statt initState.
/// Cached via Riverpod + WaterLevelService hat 15-Min-Cache.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/water_level_service.dart';
import '../effects/glass_card.dart';

final _waterLevelProvider = FutureProvider.autoDispose
    .family<List<WaterLevel>, ({double lat, double lng})>((ref, geo) async {
  try {
    return await WaterLevelService.nearby(lat: geo.lat, lng: geo.lng);
  } catch (_) {
    return const <WaterLevel>[];
  }
});

class WaterLevelWidget extends ConsumerWidget {
  const WaterLevelWidget({super.key, required this.lat, required this.lng});
  final double lat;
  final double lng;

  IconData _trendIcon(WaterTrend t) {
    switch (t) {
      case WaterTrend.rising:
        return LucideIcons.trendingUp;
      case WaterTrend.falling:
        return LucideIcons.trendingDown;
      case WaterTrend.stable:
        return LucideIcons.minus;
      case WaterTrend.unknown:
        return LucideIcons.helpCircle;
    }
  }

  Color _trendColor(WaterTrend t, {required bool warning}) {
    if (warning) return AppColors.herzrot;
    switch (t) {
      case WaterTrend.rising:
        return AppColors.amber;
      case WaterTrend.falling:
        return AppColors.lebenSoft;
      case WaterTrend.stable:
        return AppColors.tealSoft;
      case WaterTrend.unknown:
        return AppColors.mute;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_waterLevelProvider((lat: lat, lng: lng)));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final w = list.first;
        final color = _trendColor(w.trend, warning: w.warning);
        return GlassCard(
          tint: AppColors.tealSoft,
          borderColor: w.warning
              ? AppColors.herzrot.withValues(alpha: 0.5)
              : AppColors.teal.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.teal.withValues(alpha: 0.4),
                        AppColors.tealSoft.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.waves,
                      size: 16, color: AppColors.tealSoft),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pegel',
                          style: AppTypography.label(
                              size: 9, color: AppColors.tealSoft)),
                      Text(
                        w.stationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (w.warning)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.herzrot.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Hochwasser',
                        style: AppTypography.label(
                            size: 8, color: AppColors.herzrot)),
                  ),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(w.level.toStringAsFixed(0),
                    style: AppTypography.mono(
                        size: 28, color: AppColors.ink)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(w.unit,
                      style: AppTypography.label(
                          size: 10, color: AppColors.mute)),
                ),
                const Spacer(),
                Icon(_trendIcon(w.trend), size: 18, color: color),
              ]),
              if (w.water != null && w.water!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(w.water!, style: AppTypography.caption()),
              ],
            ],
          ),
        );
      },
    );
  }
}
