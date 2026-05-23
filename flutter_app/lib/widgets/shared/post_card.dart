import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';

/// SKILL: mensaena-design + mensaena-features
/// PostCard fuer Listen-Ansichten. Zeigt Typ-Badge, Titel,
/// Beschreibung, Standort, Zeit. Tippen → Detail-Seite.
class PostCard extends StatelessWidget {
  const PostCard({required this.post, super.key});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig(post.type);
    return InkWell(
      onTap: () => context.go('/dashboard/posts/${post.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cfg.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cfg.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cfg.emoji, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        cfg.label,
                        style: AppTypography.label(
                          size: 9,
                          color: cfg.color,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _relativeTime(post.createdAt),
                  style: AppTypography.body(
                    size: 11,
                    color: AppColors.mute,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: AppTypography.body(
                size: 15,
                color: AppColors.ink,
                weight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            if (post.description != null && post.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                post.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.inkSoft,
                  height: 1.45,
                ),
              ),
            ],
            if (post.locationText != null && post.locationText!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    LucideIcons.mapPin,
                    size: 12,
                    color: AppColors.mute,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      post.locationText!,
                      style: AppTypography.body(
                        size: 11,
                        color: AppColors.mute,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Action-Bar — 1:1 Pendant zu Web PostCard.tsx Z.270 ff
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.04),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _PostCardAction(
                  icon: LucideIcons.heart,
                  label: '${post.likeCount ?? 0}',
                  color: AppColors.herzrotWarm,
                ),
                const SizedBox(width: 14),
                _PostCardAction(
                  icon: LucideIcons.messageCircle,
                  label: '${post.commentCount ?? 0}',
                  color: AppColors.tealSoft,
                ),
                const SizedBox(width: 14),
                _PostCardAction(
                  icon: LucideIcons.bookmark,
                  label: '',
                  color: AppColors.bronze,
                ),
                const Spacer(),
                if (post.urgency != null && post.urgency! >= 3)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.herzrot.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertTriangle,
                            size: 9, color: AppColors.herzrotWarm),
                        const SizedBox(width: 4),
                        Text('DRINGEND',
                            style: AppTypography.label(
                                size: 7,
                                color: AppColors.herzrotWarm)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays == 1) return 'gestern';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    return DateFormat('dd.MM.yyyy').format(t);
  }
}

class _PostCardAction extends StatelessWidget {
  const _PostCardAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.mono(
                size: 11,
                color: AppColors.inkSoft,
              )),
        ],
      ],
    );
  }
}

class _TypeConfig {
  const _TypeConfig({
    required this.label,
    required this.emoji,
    required this.color,
  });
  final String label;
  final String emoji;
  final Color color;
}

_TypeConfig _typeConfig(String type) {
  switch (type) {
    case 'rescue':
      return const _TypeConfig(
        label: 'Retten',
        emoji: '🧡',
        color: Color(0xFFFB923C),
      );
    case 'animal':
      return const _TypeConfig(
        label: 'Tier',
        emoji: '🐾',
        color: Color(0xFFEC4899),
      );
    case 'housing':
      return const _TypeConfig(
        label: 'Wohnen',
        emoji: '🏡',
        color: Color(0xFF60A5FA),
      );
    case 'supply':
      return const _TypeConfig(
        label: 'Versorgung',
        emoji: '🌾',
        color: Color(0xFFFACC15),
      );
    case 'mobility':
      return const _TypeConfig(
        label: 'Mobilität',
        emoji: '🚗',
        color: Color(0xFF818CF8),
      );
    case 'sharing':
      return const _TypeConfig(
        label: 'Teilen',
        emoji: '🔄',
        color: AppColors.teal,
      );
    case 'community':
      return const _TypeConfig(
        label: 'Community',
        emoji: '🗳️',
        color: Color(0xFFC084FC),
      );
    case 'crisis':
      return const _TypeConfig(
        label: 'Notfall',
        emoji: '🚨',
        color: AppColors.herzrot,
      );
    case 'help_request':
      return const _TypeConfig(
        label: 'Hilfe gesucht',
        emoji: '🆘',
        color: AppColors.herzrot,
      );
    case 'help_offered':
      return const _TypeConfig(
        label: 'Hilfe',
        emoji: '💚',
        color: AppColors.leben,
      );
    case 'skill':
      return const _TypeConfig(
        label: 'Skill',
        emoji: '🎯',
        color: Color(0xFFA78BFA),
      );
    case 'knowledge':
      return const _TypeConfig(
        label: 'Wissen',
        emoji: '📚',
        color: AppColors.amber,
      );
    case 'mental':
      return const _TypeConfig(
        label: 'Mental',
        emoji: '🧠',
        color: AppColors.tealSoft,
      );
    default:
      return const _TypeConfig(
        label: 'Beitrag',
        emoji: '📝',
        color: AppColors.mute,
      );
  }
}
