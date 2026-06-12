/// SKILL: mensaena-features (UX-Welle1 D1)
/// "Neu in deiner Nachbarschaft" — die letzten 5 neuen User im Umkreis.
/// Cinema-Hyperreal: Horizontale Avatar-Kette mit Bronze-Ring + Tap →
/// Profil. Tap auf "Alle" → Search-Screen mit Location-Filter.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';
import '../effects/glass_card.dart';
import '../../repositories/dashboard_widgets_repository.dart';

final _nearbyNeighborsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final me = SupabaseService.currentUser?.id;
  if (me == null) return const [];
  try {
    final profile = await ProfilesRepository.getMine();
    final lat = profile?.latitude ?? profile?.homeLat;
    final lng = profile?.longitude ?? profile?.homeLng;
    if (lat == null || lng == null) return const [];
    return DashboardWidgetsRepository.nearbyNewNeighbors(
      meId: me, lat: lat, lng: lng);
  } catch (_) {
    return const [];
  }
});

class NearbyNeighborsWidget extends ConsumerWidget {
  const NearbyNeighborsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(_nearbyNeighborsProvider).maybeWhen(
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: GlassCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(LucideIcons.sparkles,
                          size: 14, color: AppColors.bronze),
                      const SizedBox(width: 6),
                      Text('neighbors.title'.tr(),
                          style: AppTypography.label(size: 11)),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            context.push('/dashboard/search'),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 0),
                            minimumSize: const Size(40, 24),
                            foregroundColor: AppColors.bronze),
                        child: Text('common.all'.tr(),
                            style: AppTypography.label(
                                size: 10, color: AppColors.bronze)),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final p = list[i];
                          final id = p['id']?.toString();
                          if (id == null) return const SizedBox.shrink();
                          final name =
                              (p['display_name'] as String?) ?? 'mensaena';
                          final avatar = p['avatar_url'] as String?;
                          return InkWell(
                            onTap: () =>
                                context.push('/dashboard/profile/$id'),
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 58,
                              child: Column(children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.bronze
                                            .withValues(alpha: 0.55),
                                        width: 1.5),
                                  ),
                                  child: ClipOval(
                                    child: avatar != null
                                        ? CachedNetworkImage(
                                            imageUrl: avatar,
                                            width: 48,
                                            height: 48,
                                            memCacheWidth: 96,
                                            memCacheHeight: 96,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                _fallback(name),
                                          )
                                        : _fallback(name),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                      size: 10, color: AppColors.inkSoft),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }

  Widget _fallback(String name) {
    return Container(
      color: AppColors.elevated,
      alignment: Alignment.center,
      width: 48,
      height: 48,
      child: Text(name[0].toUpperCase(),
          style: AppTypography.body(
              size: 18,
              color: AppColors.bronze,
              weight: FontWeight.w700)),
    );
  }
}
