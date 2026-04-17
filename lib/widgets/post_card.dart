import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/models/post.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/badge_widget.dart';
import 'package:mensaena/widgets/trust_score_badge.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final VoidCallback? onContact;
  final bool isSaved;
  final bool showActions;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onSave,
    this.onContact,
    this.isSaved = false,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final postType = post.postType;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 4)),
            BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored accent line (3px, gradient per post type)
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_getTypeColor(postType), _getTypeColor(postType).withValues(alpha: 0.2)],
                ),
              ),
            ),

            // Images
            if (post.allImages.isNotEmpty) _buildImageSection(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Author + Type Badge
                  Row(
                    children: [
                      AvatarWidget(
                        imageUrl: post.authorAvatarUrl,
                        name: post.authorName,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              timeago.format(post.createdAt, locale: 'de'),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getTypeColor(postType).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getTypeColor(postType).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '${postType.emoji} ${postType.label}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _getTypeColor(postType)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  if (post.description != null && post.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Location
                  if (post.locationText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            post.locationText!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Tags
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: post.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Urgency
                  if (post.urgency != null &&
                      post.urgency != 'normal') ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: post.urgency == 'critical'
                            ? AppColors.emergencyLight
                            : AppColors.primary50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.priority_high,
                            size: 14,
                            color: post.urgency == 'critical'
                                ? AppColors.emergency
                                : AppColors.primary500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            post.urgency == 'critical'
                                ? 'Dringend'
                                : 'Mittel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: post.urgency == 'critical'
                                  ? AppColors.emergency
                                  : AppColors.primary500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Actions
                  if (showActions) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ActionButton(
                          icon: isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          label: 'Merken',
                          isActive: isSaved,
                          onTap: onSave,
                        ),
                        const SizedBox(width: 16),
                        _ActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'Kontakt',
                          onTap: onContact,
                        ),
                        const Spacer(),
                        if (post.profile != null) ...[
                          TrustScoreBadge(
                            score: (post.profile!['trust_score'] as num?)
                                    ?.toDouble() ??
                                0,
                            size: TrustBadgeSize.small,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final images = post.allImages;
    if (images.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: AspectRatio(
        aspectRatio: images.length == 1 ? 16 / 9 : 2 / 1,
        child: images.length == 1
            ? CachedNetworkImage(
                imageUrl: images[0],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.borderLight,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.borderLight,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              )
            : Row(
                children: images.take(2).map((url) {
                  return Expanded(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      height: double.infinity,
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Color _getTypeColor(PostType type) {
    switch (type) {
      case PostType.helpNeeded:
        return AppColors.emergency;
      case PostType.helpOffered:
        return AppColors.success;
      case PostType.rescue:
        return AppColors.emergency;
      case PostType.animal:
        return AppColors.categoryAnimal;
      case PostType.housing:
        return AppColors.categoryHousing;
      case PostType.supply:
        return AppColors.primary500;
      case PostType.mobility:
        return AppColors.categoryMobility;
      case PostType.sharing:
        return AppColors.categoryCommunity;
      case PostType.crisis:
        return AppColors.emergency;
      case PostType.community:
        return AppColors.primary500;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.primary500 : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? AppColors.primary500 : AppColors.textMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
