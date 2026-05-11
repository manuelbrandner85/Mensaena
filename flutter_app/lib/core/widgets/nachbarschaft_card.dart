import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/shadows.dart';
import '../theme/typography.dart';
import 'cinema_avatar.dart';
import 'cinema_loading_skeleton.dart';
import 'kategorie_chip.dart';

/// Die "Hauptkarte" — Feed-Item, Post-Vorschau, Board-Eintrag.
/// Identische Struktur wie auf der Webseite, aber mit Cinema-Atmosphaere.
class NachbarschaftCard extends StatefulWidget {
  final PostKategorie? kategorie;
  final String? authorName;
  final String? authorAvatarUrl;
  final String timeAgo;
  final String content;
  final String? imageUrl;
  final int likeCount;
  final bool isLiked;
  final int commentCount;
  final bool isSaved;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  const NachbarschaftCard({
    super.key,
    this.kategorie,
    this.authorName,
    this.authorAvatarUrl,
    required this.timeAgo,
    required this.content,
    this.imageUrl,
    this.likeCount = 0,
    this.isLiked = false,
    this.commentCount = 0,
    this.isSaved = false,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
  });

  @override
  State<NachbarschaftCard> createState() => _NachbarschaftCardState();
}

class _NachbarschaftCardState extends State<NachbarschaftCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: MnDimensions.durMed,
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          transform: Matrix4.identity()..scale(_hover ? 1.005 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: MnColors.elevated,
            borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
            border: Border.all(
              color: _hover ? MnColors.lineActive : MnColors.line,
              width: _hover ? 1.5 : 1,
            ),
            boxShadow: _hover ? MnShadows.cardHover : MnShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.kategorie != null) ...[
                KategorieChip(kategorie: widget.kategorie!),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  CinemaAvatar(
                    imageUrl: widget.authorAvatarUrl,
                    displayName: widget.authorName,
                    size: AvatarSize.md,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.authorName ?? 'Nachbar*in',
                          style: MnTypography.body(
                            color: MnColors.ink,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.timeAgo,
                          style: MnTypography.mono(
                            size: 11,
                            color: MnColors.mute,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.content,
                style: MnTypography.body(
                  size: 15,
                  color: MnColors.inkSoft,
                  height: 1.6,
                ),
              ),
              if ((widget.imageUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const CinemaLoadingSkeleton(variant: SkeletonVariant.card),
                      errorWidget: (_, __, ___) => Container(color: MnColors.surface),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _Actions(
                isLiked: widget.isLiked,
                likeCount: widget.likeCount,
                commentCount: widget.commentCount,
                isSaved: widget.isSaved,
                onLike: widget.onLike,
                onComment: widget.onComment,
                onShare: widget.onShare,
                onSave: widget.onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final int commentCount;
  final bool isSaved;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  const _Actions({
    required this.isLiked,
    required this.likeCount,
    required this.commentCount,
    required this.isSaved,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Action(
          icon: isLiked ? LucideIcons.heart : LucideIcons.heart,
          label: likeCount.toString(),
          color: isLiked ? MnColors.herzrotWarm : MnColors.mute,
          onTap: onLike,
        ),
        const SizedBox(width: 16),
        _Action(
          icon: LucideIcons.messageSquare,
          label: commentCount.toString(),
          color: MnColors.mute,
          onTap: onComment,
        ),
        const SizedBox(width: 16),
        _Action(
          icon: LucideIcons.share2,
          color: MnColors.mute,
          onTap: onShare,
        ),
        const Spacer(),
        _Action(
          icon: isSaved ? LucideIcons.bookmark : LucideIcons.bookmark,
          color: isSaved ? MnColors.amber : MnColors.mute,
          onTap: onSave,
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback? onTap;

  const _Action({required this.icon, this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label!, style: MnTypography.mono(size: 12, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
