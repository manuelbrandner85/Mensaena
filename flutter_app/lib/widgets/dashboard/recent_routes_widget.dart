/// SKILL: mensaena-features (UX-Welle1 N3)
/// "Zuletzt besucht" — horizontale Chip-Liste der 5 letzten Module/Screens.
///
/// Nutzt das bestehende RecentPagesService das nur Routes speichert; das
/// Widget mappt Route → Title + Icon via Heuristik.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/recent_pages_service.dart';

class _RouteInfo {
  const _RouteInfo({required this.title, required this.icon});
  final String title;
  final IconData icon;
}

_RouteInfo _routeInfo(String route) {
  if (route.startsWith('/dashboard/map')) {
    return _RouteInfo(title: 'nav.map'.tr(), icon: LucideIcons.map);
  }
  if (route.startsWith('/dashboard/events')) {
    return _RouteInfo(title: 'nav.events'.tr(), icon: LucideIcons.calendar);
  }
  if (route.startsWith('/dashboard/marketplace')) {
    return _RouteInfo(
        title: 'nav.marketplace'.tr(), icon: LucideIcons.shoppingBag);
  }
  if (route.startsWith('/dashboard/groups')) {
    return _RouteInfo(title: 'nav.groups'.tr(), icon: LucideIcons.users);
  }
  if (route.startsWith('/dashboard/wiki')) {
    return const _RouteInfo(title: 'Wiki', icon: LucideIcons.bookOpen);
  }
  if (route.startsWith('/dashboard/knowledge')) {
    return const _RouteInfo(title: 'Bildung', icon: LucideIcons.graduationCap);
  }
  if (route.startsWith('/dashboard/skills')) {
    return const _RouteInfo(title: 'Skills', icon: LucideIcons.wrench);
  }
  if (route.startsWith('/dashboard/mentorship')) {
    return const _RouteInfo(title: 'Mentoring', icon: LucideIcons.users);
  }
  if (route.startsWith('/dashboard/animals')) {
    return const _RouteInfo(title: 'Tiere', icon: LucideIcons.heart);
  }
  if (route.startsWith('/dashboard/housing')) {
    return const _RouteInfo(title: 'Wohnen', icon: LucideIcons.home);
  }
  if (route.startsWith('/dashboard/jobs')) {
    return const _RouteInfo(title: 'Jobs', icon: LucideIcons.briefcase);
  }
  if (route.startsWith('/dashboard/supply')) {
    return const _RouteInfo(title: 'Versorgung', icon: LucideIcons.utensils);
  }
  if (route.startsWith('/dashboard/harvest')) {
    return const _RouteInfo(title: 'Ernten', icon: LucideIcons.utensils);
  }
  if (route.startsWith('/dashboard/mobility')) {
    return const _RouteInfo(title: 'Mobilität', icon: LucideIcons.car);
  }
  if (route.startsWith('/dashboard/crisis')) {
    return const _RouteInfo(title: 'Krise', icon: LucideIcons.shieldAlert);
  }
  if (route.startsWith('/dashboard/charge-stations')) {
    return const _RouteInfo(title: 'E-Lade', icon: LucideIcons.zap);
  }
  if (route.startsWith('/dashboard/board')) {
    return const _RouteInfo(title: 'Pinnwand', icon: LucideIcons.pin);
  }
  if (route.startsWith('/dashboard/challenges')) {
    return const _RouteInfo(title: 'Challenges', icon: LucideIcons.target);
  }
  if (route.startsWith('/dashboard/badges')) {
    return const _RouteInfo(title: 'Badges', icon: LucideIcons.award);
  }
  if (route.startsWith('/dashboard/organizations')) {
    return const _RouteInfo(title: 'Organisationen', icon: LucideIcons.building);
  }
  if (route.startsWith('/dashboard/calendar')) {
    return const _RouteInfo(title: 'Kalender', icon: LucideIcons.calendar);
  }
  return _RouteInfo(title: route.split('/').last, icon: LucideIcons.compass);
}

final recentRoutesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final all = await RecentPagesService.getRecent();
  // Filtere uninteressante Top-Level-Routes raus.
  const skip = {
    '/dashboard',
    '/dashboard/profile',
    '/dashboard/messages',
    '/dashboard/map',
    '/dashboard/search',
    '/auth',
    '/login',
    '/splash',
  };
  final filtered = all.where((r) {
    if (skip.contains(r)) return false;
    // Detail-Screens mit IDs überspringen (last segment = UUID/long-id)
    final segs = r.split('/');
    final last = segs.last;
    if (last.length >= 20 ||
        RegExp(r'^[0-9a-f-]{8,}$').hasMatch(last)) {
      return false;
    }
    return true;
  }).toList();
  return filtered.take(5).toList();
});

class RecentRoutesWidget extends ConsumerWidget {
  const RecentRoutesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(recentRoutesProvider).maybeWhen(
          data: (items) {
            if (items.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                    child: Row(children: [
                      const Icon(LucideIcons.clock,
                          size: 13, color: AppColors.bronze),
                      const SizedBox(width: 6),
                      Text('recent.title'.tr(),
                          style: AppTypography.label(size: 10)),
                    ]),
                  ),
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final r = items[i];
                        final info = _routeInfo(r);
                        return InkWell(
                          onTap: () => context.push(r),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 80,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.55),
                              border: Border.all(
                                  color: AppColors.bronze
                                      .withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(info.icon,
                                      size: 18, color: AppColors.bronze),
                                  const SizedBox(height: 4),
                                  Text(
                                    info.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body(
                                        size: 10,
                                        color: AppColors.ink,
                                        weight: FontWeight.w600),
                                  ),
                                ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }
}
