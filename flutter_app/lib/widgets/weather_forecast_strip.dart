import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/weather.dart';
import '../theme/app_colors.dart';

/// Pendant zur Web-`WeatherForecastStrip`: 7-Tage-Vorhersage als
/// horizontaler Strip — pro Tag Wochentag, Wetter-Emoji, Min/Max.
/// Bei null lat/lng (z. B. fehlende Geo-Erlaubnis) wird nichts gerendert.
class WeatherForecastStrip extends StatefulWidget {
  const WeatherForecastStrip({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double? latitude;
  final double? longitude;

  @override
  State<WeatherForecastStrip> createState() => _WeatherForecastStripState();
}

class _WeatherForecastStripState extends State<WeatherForecastStrip> {
  List<WeatherForecastDay> _days = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WeatherForecastStrip old) {
    super.didUpdateWidget(old);
    if (old.latitude != widget.latitude ||
        old.longitude != widget.longitude) {
      _load();
    }
  }

  Future<void> _load() async {
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat == null || lng == null) {
      setState(() {
        _days = const [];
        _loaded = true;
      });
      return;
    }
    final list = await WeatherService.fetch(latitude: lat, longitude: lng);
    if (!mounted) return;
    setState(() {
      _days = list;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _days.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => _DayTile(day: _days[i]),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});
  final WeatherForecastDay day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = day.date.year == today.year &&
        day.date.month == today.month &&
        day.date.day == today.day;
    final wd = isToday ? 'Heute' : DateFormat('E', 'de').format(day.date);
    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.primary500.withValues(alpha: 0.1)
            : AppColors.stone100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday
              ? AppColors.primary500.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            wd,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isToday ? AppColors.primary500 : AppColors.ink700,
            ),
          ),
          Text(
            day.emoji,
            style: const TextStyle(fontSize: 20),
          ),
          Text(
            '${day.tempMin.round()}° / ${day.tempMax.round()}°',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.ink800,
            ),
          ),
        ],
      ),
    );
  }
}
