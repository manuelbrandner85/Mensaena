/// WeatherWidget V3 — Provider statt initState, Tap öffnet WeatherScreen.
/// Cached via Riverpod, kein doppelter HTTP-Request bei Rebuild.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/weather_service.dart';
import 'tile_error.dart';

final _weatherProvider = FutureProvider.autoDispose
    .family<List<WeatherDay>, ({double lat, double lng})>((ref, geo) async {
  try {
    return await WeatherService.forecast(
      latitude: geo.lat,
      longitude: geo.lng,
      days: 1,
    );
  } catch (_) {
    return const <WeatherDay>[];
  }
});

class WeatherWidget extends ConsumerWidget {
  const WeatherWidget({super.key, required this.lat, required this.lng});
  final double lat;
  final double lng;

  String _tip(WeatherDay d) {
    if (d.code >= 95) {
      return 'Gewitter – drinnen bleiben und Nachbarn informieren. ⚡';
    }
    if (d.code >= 71 && d.code <= 77) {
      return 'Schnee – Gehwege freihalten! Hilf älteren Nachbarn. 🏠';
    }
    if (d.tempMin < 0) return 'Frost! Hilf älteren Nachbarn beim Räumen. 🧤';
    if (d.code >= 61 && d.code <= 67) {
      return 'Hast du einen Regenschirm übrig? Deine Nachbarn danken es dir. ☂️';
    }
    if (d.code == 45 || d.code == 48) {
      return 'Nebel – Vorsicht beim Radfahren und zu Fuß. 🚶';
    }
    if (d.tempMax >= 30) return 'Heiß! Biete deinen Nachbarn etwas Wasser an. 💧';
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_weatherProvider((lat: lat, lng: lng)));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => DashboardTileError(onRetry: () => ref.invalidate(_weatherProvider)),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final d = list.first;
        final tip = _tip(d);
        return GestureDetector(
          onTap: () => context.push(
            '/dashboard/weather',
            extra: {'lat': lat, 'lng': lng},
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(d.emoji, style: const TextStyle(fontSize: 28, height: 1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('home.currentWeather'.tr(),
                            style: AppTypography.label(
                                size: 9, color: AppColors.mute)),
                        const SizedBox(height: 2),
                        RichText(
                          text: TextSpan(
                            style: AppTypography.body(
                                size: 14,
                                color: AppColors.ink,
                                weight: FontWeight.w700),
                            children: [
                              TextSpan(
                                  text:
                                      '${d.tempMax.round()}° / ${d.tempMin.round()}°'),
                              TextSpan(
                                text: '  ${d.label}',
                                style: AppTypography.body(
                                    size: 12,
                                    color: AppColors.mute,
                                    weight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight,
                      size: 16, color: AppColors.mute),
                ]),
                if (tip.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bronze.withValues(alpha: 0.08),
                      border: Border.all(
                          color: AppColors.bronze.withValues(alpha: 0.18)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(tip,
                        style: AppTypography.body(
                            size: 11,
                            color: AppColors.inkSoft,
                            height: 1.4)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class WeatherLocationCta extends StatelessWidget {
  const WeatherLocationCta({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Text('🌤️', style: TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('home.weatherUnlockTitle'.tr(),
                  style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('home.weatherUnlockBody'.tr(),
                  style: AppTypography.body(
                      size: 12, color: AppColors.inkSoft, height: 1.4)),
            ],
          ),
        ),
        const Icon(LucideIcons.chevronRight,
            size: 16, color: AppColors.mute),
      ]),
    );
  }
}
