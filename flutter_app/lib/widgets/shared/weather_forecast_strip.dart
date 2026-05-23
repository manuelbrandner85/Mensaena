import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/weather_service.dart';

/// SKILL: mensaena-features
/// 5-Tages-Wetter-Strip — Pendant zu Web `WeatherForecastStrip.tsx`
/// (in `src/app/dashboard/events/components/`).
class WeatherForecastStrip extends ConsumerWidget {
  const WeatherForecastStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecast = ref.watch(_weatherProvider);
    return forecast.when(
      loading: () => Container(
        height: 76,
        margin:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.amber,
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (days) {
        if (days.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final d in days) Expanded(child: _DayCell(day: d)),
            ],
          ),
        );
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});
  final WeatherDay day;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('E', 'de');
    final isToday = DateUtils.isSameDay(day.date, DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.amber.withValues(alpha: 0.16)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            df.format(day.date).substring(0, 2),
            style: AppTypography.label(
              size: 9,
              color: isToday ? AppColors.amber : AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 2),
          Text(day.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            '${day.tempMax.toStringAsFixed(0)}°',
            style: AppTypography.mono(
              size: 11,
              color: AppColors.ink,
            ),
          ),
          Text(
            '${day.tempMin.toStringAsFixed(0)}°',
            style: AppTypography.mono(size: 9, color: AppColors.mute),
          ),
        ],
      ),
    );
  }
}

final _weatherProvider = FutureProvider<List<WeatherDay>>((ref) async {
  try {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      // Default: Wien
      return WeatherService.forecast(latitude: 48.2082, longitude: 16.3738);
    }
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
    return WeatherService.forecast(
      latitude: pos.latitude,
      longitude: pos.longitude,
    );
  } catch (_) {
    return WeatherService.forecast(latitude: 48.2082, longitude: 16.3738);
  }
});
