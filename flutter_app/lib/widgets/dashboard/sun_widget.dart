/// SKILL: mensaena-features + mensaena-design
/// Sun-Widget — Sonnenauf/-untergang fuer User-Standort.
library;

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
