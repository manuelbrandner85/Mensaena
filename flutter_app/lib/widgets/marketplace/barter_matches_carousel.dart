/// SKILL: mensaena-features (Phase 7 F67)
/// Tausch-Matching — bei listing_type='tauschen' werden andere
/// Tausch-Listings derselben Kategorie als potentielle Tausch-Partner
/// vorgeschlagen.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/marketplace_repository.dart';

final _barterMatchesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _BarterKey>((ref, key) async {
  try {
    return MarketplaceRepository.barterMatches(
        listingId: key.listingId, category: key.category);
  } catch (_) {
    return const [];
  }
});

class BarterMatchesCarousel extends ConsumerWidget {
  const BarterMatchesCarousel({
    required this.listingId,
    required this.category,
    required this.listingType,
    super.key,
  });

  final String listingId;
  final String category;
  final String listingType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listingType != 'tauschen') return const SizedBox.shrink();
    final async =
        ref.watch(_barterMatchesProvider(_BarterKey(listingId, category)));
    return async.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
                child: Row(children: [
                  const Icon(LucideIcons.repeat,
                      size: 13, color: AppColors.tealSoft),
                  const SizedBox(width: 6),
                  Text(
                    'marketplace.barterMatchesTitle'.tr(),
                    style: AppTypography.label(size: 10),
                  ),
                ]),
              ),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _BarterTile(item: list[i]),
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

class _BarterKey {
  const _BarterKey(this.listingId, this.category);
  final String listingId;
  final String category;
  @override
  bool operator ==(Object other) =>
      other is _BarterKey &&
      other.listingId == listingId &&
      other.category == category;
  @override
  int get hashCode => Object.hash(listingId, category);
}

class _BarterTile extends StatelessWidget {
  const _BarterTile({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final id = item['id'] as String;
    final title = (item['title'] as String?) ?? '—';
    // images bevorzugt, image_urls als Fallback (beide Array-Spalten).
    final imgs = (item['images'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final altImgs =
        (item['image_urls'] as List?)?.whereType<String>().toList() ??
            const <String>[];
    final imageUrl = imgs.isNotEmpty
        ? imgs.first
        : (altImgs.isNotEmpty ? altImgs.first : null);
    return InkWell(
      onTap: () => context.push('/dashboard/marketplace/$id'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(
              color: AppColors.tealSoft.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                height: 72,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 280,
              )
            else
              Container(
                height: 72,
                width: double.infinity,
                alignment: Alignment.center,
                color: AppColors.elevated,
                child: const Icon(LucideIcons.repeat,
                    color: AppColors.tealSoft, size: 22),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                    size: 11,
                    color: AppColors.ink,
                    weight: FontWeight.w600,
                    height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
