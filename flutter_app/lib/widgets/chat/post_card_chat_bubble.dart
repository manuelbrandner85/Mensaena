/// SKILL: mensaena-features (Phase 1 F26)
/// Inline-Chat-Bubble die einen `[POSTCARD:<postId>]`-Marker als kompakte
/// Post-Vorschau rendert. Wird beim ersten Eintreten in eine neu erstellte
/// DM-aus-Post automatisch eingefügt.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/posts_repository.dart';

final _postPreviewProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, postId) async {
    try {
      return PostsRepository.cardPreview(postId);
    } catch (_) {
      return null;
    }
  },
);

class PostCardChatBubble extends ConsumerWidget {
  const PostCardChatBubble({required this.postId, super.key});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_postPreviewProvider(postId));
    return async.when(
      loading: () => const SizedBox(
        height: 84,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.bronze),
          ),
        ),
      ),
      error: (_, __) => _fallback(context),
      data: (post) {
        if (post == null) return _fallback(context);
        final title = (post['title'] as String?) ?? '—';
        final type = (post['type'] as String?) ?? 'post';
        final imageList = (post['images'] as List?)?.cast<String>() ??
            const <String>[];
        final imageUrl = imageList.isNotEmpty
            ? imageList.first
            : (post['image_url'] as String?);
        return InkWell(
          onTap: () => context.push('/dashboard/posts/$postId'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.55),
              border:
                  Border.all(color: AppColors.bronze.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11),
                      bottomLeft: Radius.circular(11),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                    ),
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(11),
                        bottomLeft: Radius.circular(11),
                      ),
                    ),
                    child: const Icon(LucideIcons.fileText,
                        color: AppColors.bronze, size: 24),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'chat.postCardLabel'.tr(),
                          style: AppTypography.label(
                              size: 9, color: AppColors.bronze),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                              size: 13,
                              color: AppColors.ink,
                              weight: FontWeight.w600,
                              height: 1.2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'post.types.$type',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(),
                        ).tr(),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(LucideIcons.chevronRight,
                      size: 14, color: AppColors.mute),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fallback(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/dashboard/posts/$postId'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.fileText,
                size: 14, color: AppColors.bronze),
            const SizedBox(width: 8),
            Text(
              'chat.postCardFallback'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
