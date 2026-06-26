/// SKILL: mensaena-features (Phase 6 F74)
/// Zeigt Gruppen im 5-km-Umkreis basierend auf aktueller GPS-Position.
/// Bleibt unsichtbar wenn GPS nicht verfügbar oder keine Treffer.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/group.dart';
import '../../repositories/groups_repository.dart';
import '../../services/location_service.dart';

final _nearbyGroupsProvider =
    FutureProvider.autoDispose<List<Group>>((ref) async {
  try {
    final pos = await LocationService.getCurrentPosition()
        .timeout(const Duration(seconds: 6));
    return GroupsRepository.nearby(
      lat: pos.latitude,
      lng: pos.longitude,
      radiusKm: 5,
      limit: 10,
    );
  } catch (_) {
    return const [];
  }
});

class NearbyGroupsCarousel extends ConsumerWidget {
  const NearbyGroupsCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_nearbyGroupsProvider);
    return async.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Row(children: [
                  const Icon(LucideIcons.mapPin,
                      size: 13, color: AppColors.leben),
                  const SizedBox(width: 6),
                  Text(
                    'groups.nearbyTitle'.tr(),
                    style: AppTypography.label(size: 10),
                  ),
                ]),
              ),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _NearbyTile(group: list[i]),
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

class _NearbyTile extends StatelessWidget {
  const _NearbyTile({required this.group});
  final Group group;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/dashboard/groups/${group.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.55),
          border: Border.all(color: AppColors.leben.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.bannerUrl != null && group.bannerUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: group.bannerUrl!,
                height: 60,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 280,
              )
            else
              Container(
                height: 60,
                width: double.infinity,
                alignment: Alignment.center,
                color: AppColors.elevated,
                child: const Icon(LucideIcons.users2,
                    color: AppColors.leben, size: 22),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                        size: 12,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                        height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'groups.memberCount'
                        .tr(namedArgs: {'count': '${group.memberCount}'}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
