/// SKILL: mensaena-features + mensaena-design
/// Sun-Widget — Sonnenauf/-untergang fuer User-Standort.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/sun_service.dart';
import '../effects/glass_card.dart';

final _sunProvider = FutureProvider<SunData?>((ref) async {
  final p = await ProfilesRepository.getMine();
  final lat = p?.latitude ?? p?.homeLat;
  final lng = p?.longitude ?? p?.homeLng;
  if (lat == null || lng == null) return null;
  return SunService.fetchForPosition(lat: lat, lng: lng);
});

class SunWidget extends ConsumerWidget {
  const SunWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_sunProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (sun) {
        if (sun == null) return const SizedBox.shrink();
        final fmt = DateFormat.Hm();
        final dayLength = sun.dayLength;
        final hh = dayLength.inHours;
        final mm = dayLength.inMinutes % 60;
        final isGolden = sun.isGoldenHourNow;
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: InkWell(
            onTap: () => _SunPathSheet.show(context, sun),
            borderRadius: BorderRadius.circular(8),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    sun.isNight ? LucideIcons.moon : LucideIcons.sun,
                    size: 16,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 8),
                  Text('sun.title'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                  const Spacer(),
                  if (isGolden)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.amber.withValues(alpha: 0.4),
                          AppColors.amberWarm.withValues(alpha: 0.4),
                        ]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('sun.goldenHour'.tr(),
                          style: AppTypography.label(
                              size: 9, color: AppColors.amberWarm)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Stat(
                    icon: LucideIcons.sunrise,
                    label: 'sun.sunrise'.tr(),
                    value: fmt.format(sun.sunrise.toLocal()),
                  ),
                  const SizedBox(width: 16),
                  _Stat(
                    icon: LucideIcons.sunset,
                    label: 'sun.sunset'.tr(),
                    value: fmt.format(sun.sunset.toLocal()),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('sun.dayLength'.tr(),
                          style: AppTypography.label(size: 9)),
                      Text('${hh}h ${mm}m',
                          style: AppTypography.mono(
                              size: 12,
                              color: AppColors.amber,
                              weight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.amber),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.label(size: 9)),
            Text(value,
                style: AppTypography.mono(
                    size: 12,
                    color: AppColors.ink,
                    weight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

/// F63: Sun-Path-Sheet — Sonnenstand-Halbkreis mit aktueller Position.
class _SunPathSheet extends StatelessWidget {
  const _SunPathSheet({required this.sun});
  final SunData sun;

  static Future<void> show(BuildContext context, SunData sun) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SunPathSheet(sun: sun),
    );
  }

  /// 0..1 Anteil heute-Tag: <=0 vor Sonnenaufgang, >=1 nach Untergang.
  double _todayProgress() {
    final now = DateTime.now();
    final rise = sun.sunrise.toLocal();
    final set = sun.sunset.toLocal();
    if (now.isBefore(rise)) return 0;
    if (now.isAfter(set)) return 1;
    final total = set.difference(rise).inSeconds;
    if (total <= 0) return 0;
    return now.difference(rise).inSeconds / total;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.Hm();
    final progress = _todayProgress();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sun,
                  size: 20, color: AppColors.amber),
              const SizedBox(width: 8),
              Text('sun.pathTitle'.tr(),
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SunArcPainter(progress: progress),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('sun.sunrise'.tr(),
                      style: AppTypography.caption()),
                  Text(fmt.format(sun.sunrise.toLocal()),
                      style: AppTypography.mono(
                          size: 14,
                          color: AppColors.amber,
                          weight: FontWeight.w700)),
                ],
              ),
              Column(
                children: [
                  Text('sun.solarNoon'.tr(),
                      style: AppTypography.caption()),
                  Text(fmt.format(sun.solarNoon.toLocal()),
                      style: AppTypography.mono(
                          size: 14,
                          color: AppColors.amberWarm,
                          weight: FontWeight.w700)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('sun.sunset'.tr(),
                      style: AppTypography.caption()),
                  Text(fmt.format(sun.sunset.toLocal()),
                      style: AppTypography.mono(
                          size: 14,
                          color: AppColors.amber,
                          weight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SunArcPainter extends CustomPainter {
  _SunArcPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h;
    final r = math.min(w / 2 - 12, h - 12);

    // Arc-Pfad
    final arc = Path()
      ..moveTo(cx - r, cy)
      ..arcToPoint(
        Offset(cx + r, cy),
        radius: Radius.circular(r),
        clockwise: true,
      );
    final arcPaint = Paint()
      ..color = AppColors.amber.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(arc, arcPaint);

    // Horizont-Linie
    final horizonPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(8, cy), Offset(w - 8, cy), horizonPaint);

    // Sonnen-Position
    final angle = math.pi * (1 - progress.clamp(0.0, 1.0));
    final sx = cx + r * math.cos(angle);
    final sy = cy - r * math.sin(angle);

    // Bloom-Glow
    canvas.drawCircle(
      Offset(sx, sy),
      18,
      Paint()..color = AppColors.amber.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      8,
      Paint()..color = AppColors.amberWarm,
    );

    // Sunrise/Sunset Marker-Punkte
    final markerPaint = Paint()..color = AppColors.amber;
    canvas.drawCircle(Offset(cx - r, cy), 3, markerPaint);
    canvas.drawCircle(Offset(cx + r, cy), 3, markerPaint);
  }

  @override
  bool shouldRepaint(covariant _SunArcPainter old) =>
      old.progress != progress;
}
