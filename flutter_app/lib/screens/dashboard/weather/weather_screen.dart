import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/weather_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _weatherScreenForecastProvider =
    FutureProvider.autoDispose.family<List<WeatherDay>, ({double lat, double lng})>(
  (ref, geo) => WeatherService.forecast(latitude: geo.lat, longitude: geo.lng),
);

final _weatherScreenHourlyProvider =
    FutureProvider.autoDispose.family<List<WeatherHourly>, ({double lat, double lng})>(
  (ref, geo) => WeatherService.hourly(latitude: geo.lat, longitude: geo.lng),
);

final _weatherScreenAqProvider =
    FutureProvider.autoDispose.family<AirQuality?, ({double lat, double lng})>(
  (ref, geo) => WeatherService.airQuality(latitude: geo.lat, longitude: geo.lng),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geo = (lat: lat, lng: lng);
    final forecast = ref.watch(_weatherScreenForecastProvider(geo));
    final hourly = ref.watch(_weatherScreenHourlyProvider(geo));
    final aq = ref.watch(_weatherScreenAqProvider(geo));

    return DashboardScaffold(
      title: 'weather.title'.tr(),
      currentRoute: '/dashboard/weather',
      appBarActions: [
        IconButton(
          icon: const Icon(LucideIcons.refreshCw, size: 18),
          tooltip: 'weather.refresh'.tr(),
          onPressed: () {
            WeatherService.clearCache();
            ref.invalidate(_weatherScreenForecastProvider);
            ref.invalidate(_weatherScreenHourlyProvider);
            ref.invalidate(_weatherScreenAqProvider);
          },
        ),
      ],
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Aktuelles Wetter ─────────────────────────────────────────
            forecast.when(
              loading: () => _LoadingCard(height: 120),
              error: (_, __) => _ErrorCard(
                onRetry: () => ref.invalidate(_weatherScreenForecastProvider),
              ),
              data: (days) => days.isEmpty
                  ? const SizedBox.shrink()
                  : _CurrentWeatherCard(day: days.first),
            ),

            const SizedBox(height: 16),

            // ── Stündliche Temperaturkurve ───────────────────────────────
            _SectionHeader(label: 'weather.hourlyForecast'.tr()),
            const SizedBox(height: 8),
            hourly.when(
              loading: () => _LoadingCard(height: 160),
              error: (_, __) => _ErrorCard(
                onRetry: () => ref.invalidate(_weatherScreenHourlyProvider),
              ),
              data: (points) => points.isEmpty
                  ? const SizedBox.shrink()
                  : _TempCurveCard(hours: points),
            ),

            const SizedBox(height: 16),

            // ── Luftqualität ──────────────────────────────────────────────
            _SectionHeader(label: 'weather.airQuality'.tr()),
            const SizedBox(height: 8),
            aq.when(
              loading: () => _LoadingCard(height: 100),
              error: (_, __) => const SizedBox.shrink(),
              data: (quality) => quality == null
                  ? const SizedBox.shrink()
                  : _AirQualityCard(aq: quality),
            ),

            const SizedBox(height: 16),

            // ── 5-Tages-Vorschau ──────────────────────────────────────────
            _SectionHeader(label: 'weather.dailyForecast'.tr()),
            const SizedBox(height: 8),
            forecast.when(
              loading: () => _LoadingCard(height: 200),
              error: (_, __) => const SizedBox.shrink(),
              data: (days) => days.isEmpty
                  ? const SizedBox.shrink()
                  : _DailyForecastCard(days: days),
            ),

            const SizedBox(height: 16),

            // ── Quelle ────────────────────────────────────────────────────
            Text(
              'weather.source'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.caption(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Aktuelles Wetter ──────────────────────────────────────────────────────────

class _CurrentWeatherCard extends StatelessWidget {
  const _CurrentWeatherCard({required this.day});
  final WeatherDay day;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Text(day.emoji, style: const TextStyle(fontSize: 56, height: 1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.tempMax.round()}° / ${day.tempMin.round()}°',
                  style: AppTypography.display(size: 28),
                ),
                const SizedBox(height: 4),
                Text(
                  day.labelKey.tr(),
                  style: AppTypography.body(size: 14, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(LucideIcons.droplets,
                        size: 13, color: AppColors.tealSoft),
                    const SizedBox(width: 4),
                    Text(
                      '${'weather.precipitation'.tr()}: '
                      '${day.precipitationMm.toStringAsFixed(1)} mm',
                      style: AppTypography.caption(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stündliche Temperaturkurve ────────────────────────────────────────────────

class _TempCurveCard extends StatelessWidget {
  const _TempCurveCard({required this.hours});
  final List<WeatherHourly> hours;

  @override
  Widget build(BuildContext context) {
    final temps = hours.map((h) => h.tempC).toList();
    final minT = temps.reduce(math.min);
    final maxT = temps.reduce(math.max);
    final padding = (maxT - minT) < 2 ? 2.0 : 2.0;

    final spots = <FlSpot>[];
    for (var i = 0; i < hours.length; i++) {
      spots.add(FlSpot(i.toDouble(), hours[i].tempC));
    }

    return _Card(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: minT - padding,
                maxY: maxT + padding,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.line,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text(
                        '${v.round()}°',
                        style:
                            AppTypography.body(size: 10, color: AppColors.mute),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 4,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= hours.length) {
                          return const SizedBox.shrink();
                        }
                        final h = hours[idx].time.hour;
                        return Text(
                          '${h.toString().padLeft(2, '0')}h',
                          style: AppTypography.body(
                              size: 10, color: AppColors.mute),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.primary500,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary500.withValues(alpha: 0.28),
                          AppColors.primary500.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        AppColors.elevated.withValues(alpha: 0.95),
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(1)}°',
                              AppTypography.body(
                                  size: 12,
                                  color: AppColors.ink,
                                  weight: FontWeight.w600),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${'weather.low'.tr()}: ${minT.toStringAsFixed(1)}°',
                style: AppTypography.caption(),
              ),
              Text(
                '${'weather.high'.tr()}: ${maxT.toStringAsFixed(1)}°',
                style:
                    AppTypography.body(size: 12, color: AppColors.bronzeSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Luftqualität ──────────────────────────────────────────────────────────────

class _AirQualityCard extends StatelessWidget {
  const _AirQualityCard({required this.aq});
  final AirQuality aq;

  @override
  Widget build(BuildContext context) {
    final color = aq.aqiColor;
    final fraction = (aq.europeanAqi / 100).clamp(0.0, 1.0);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aq.aqiLabelKey.tr(),
                      style: AppTypography.body(
                          size: 16,
                          color: color,
                          weight: FontWeight.w700),
                    ),
                    Text(
                      '${'weather.aqi'.tr()}: ${aq.europeanAqi}',
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              _AqiPill(
                label: 'PM2.5',
                value: '${aq.pm25.toStringAsFixed(1)} µg',
              ),
              const SizedBox(width: 8),
              _AqiPill(
                label: 'PM10',
                value: '${aq.pm10.toStringAsFixed(1)} µg',
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.elevated,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AqiPill extends StatelessWidget {
  const _AqiPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label,
              style: AppTypography.body(size: 9, color: AppColors.mute)),
          Text(value,
              style: AppTypography.mono(size: 11, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

// ── 5-Tages-Vorschau ──────────────────────────────────────────────────────────

class _DailyForecastCard extends StatelessWidget {
  const _DailyForecastCard({required this.days});
  final List<WeatherDay> days;

  @override
  Widget build(BuildContext context) {
    final tempMax = days.map((d) => d.tempMax).reduce(math.max);
    final tempMin = days.map((d) => d.tempMin).reduce(math.min);

    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: days.map((d) {
          final isFirst = d == days.first;
          return _DayRow(
            day: d,
            globalMin: tempMin,
            globalMax: tempMax,
            isToday: isFirst,
          );
        }).toList(),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.globalMin,
    required this.globalMax,
    required this.isToday,
  });
  final WeatherDay day;
  final double globalMin;
  final double globalMax;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final range = (globalMax - globalMin).clamp(1.0, double.infinity);
    final barStart = (day.tempMin - globalMin) / range;
    final barEnd = (day.tempMax - globalMin) / range;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              isToday
                  ? 'weather.today'.tr()
                  : DateFormat('EEE', 'de').format(day.date),
              style: AppTypography.body(
                size: 13,
                color: isToday ? AppColors.bronzeSoft : AppColors.inkSoft,
                weight: isToday ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(day.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${day.tempMin.round()}°',
              textAlign: TextAlign.end,
              style: AppTypography.mono(size: 12, color: AppColors.mute),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final w = constraints.maxWidth;
                  return Stack(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Positioned(
                        left: w * barStart,
                        width: (w * (barEnd - barStart)).clamp(4.0, w),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.tealSoft, AppColors.bronzeSoft],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${day.tempMax.round()}°',
              textAlign: TextAlign.start,
              style: AppTypography.mono(size: 12, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hilfs-Widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.label(size: 11, color: AppColors.mute),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary500,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.cloudOff, size: 16, color: AppColors.mute),
          const SizedBox(width: 8),
          Text('weather.loadError'.tr(),
              style: AppTypography.body(size: 13, color: AppColors.mute)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'weather.retry'.tr(),
              style: AppTypography.body(
                  size: 13,
                  color: AppColors.primary500,
                  weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
