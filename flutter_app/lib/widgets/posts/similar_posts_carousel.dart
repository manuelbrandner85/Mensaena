/// SKILL: mensaena-features (Phase 7 F41)
/// "Ähnliche Beiträge" — horizontale Carousel unter PostDetail.
/// Query: gleicher type, Tag-Overlap, andere ID, max 5, sortiert nach
/// created_at desc.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

final _similarPostsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _SimilarKey>((ref, key) async {
  try {
    var q = sb
        .from('posts')
        .select('id, title, type, media_urls, image_url, created_at')
        .neq('id', key.postId)
        .eq('status', 'active')
        .eq('type', key.type);
    if (key.tags.isNotEmpty) {
      // Postgres array overlap operator via Supabase
      q = q.overlaps('tags', key.tags);
    }
    final rows = await q.order('created_at', ascending: false).limit(5);
    return (rows as List).whereType<Map<String, dynamic>>().toList();
  } catch (_) {
    return const [];
  }
});

class SimilarPostsCarousel extends ConsumerWidget {
  const SimilarPostsCarousel({
    required this.postId,
    required this.type,
    this.tags = const [],
    super.key,
  });
  final String postId;
  final String type;
  final List<String> tags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      _similarPostsProvider(_SimilarKey(postId, type, tags)),
    );
    return async.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(children: [
                  const Icon(LucideIcons.layers,
                      size: 13, color: AppColors.bronze),
                  const SizedBox(width: 6),
                  Text(
                    'posts.similarTitle'.tr(),
                    style: AppTypography.label(size: 10),
                  ),
                ]),
              ),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _SimilarTile(post: list[i]),
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

class _SimilarKey {
  const _SimilarKey(this.postId, this.type, this.tags);
  final String postId;
  final String type;
  final List<String> tags;

  @override
  bool operator ==(Object other) =>
      other is _SimilarKey &&
      other.postId == postId &&
      other.type == type &&
      _listEq(other.tags, tags);

  @override
  int get hashCode => Object.hash(postId, type, Object.hashAll(tags));

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _SimilarTile extends StatelessWidget {
  const _SimilarTile({required this.post});
  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    final id = post['id']?.toString() ?? '';
    final title = (post['title'] as String?) ?? '—';
    final media = (post['media_urls'] as List?)?.cast<String>() ??
        const <String>[];
    final imageUrl = media.isNotEmpty
        ? media.first
        : (post['image_url'] as String?);
    return InkWell(
      onTap: () => context.push('/dashboard/posts/$id'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                height: 78,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 280,
              )
            else
              Container(
                height: 78,
                width: double.infinity,
                alignment: Alignment.center,
                color: AppColors.elevated,
                child: const Icon(LucideIcons.fileText,
                    color: AppColors.bronze, size: 24),
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
