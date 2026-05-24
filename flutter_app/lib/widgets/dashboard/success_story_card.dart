/// SKILL: mensaena-features
/// SuccessStoryCard — Rotierende anonyme Erfolgsgeschichten.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import '../effects/shimmer_skeleton.dart';

class SuccessStoryCard extends StatefulWidget {
  const SuccessStoryCard({super.key});

  @override
  State<SuccessStoryCard> createState() => _SuccessStoryCardState();
}

class _SuccessStoryCardState extends State<SuccessStoryCard> {
  Future<Map<String, dynamic>?>? _future;
  bool _rotating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    try {
      List<Map<String, dynamic>> data;
      try {
        final rows = await sb
            .from('success_stories')
            .select(
                'id, title, body, image_url, profiles!success_stories_author_id_fkey(name, location)')
            .eq('is_approved', true)
            .order('created_at', ascending: false)
            .limit(20);
        data = (rows as List).whereType<Map<String, dynamic>>().toList();
      } catch (_) {
        final rows = await sb
            .from('success_stories')
            .select(
                'id, title, body, profiles!success_stories_author_id_fkey(name, location)')
            .eq('is_approved', true)
            .order('created_at', ascending: false)
            .limit(20);
        data = (rows as List).whereType<Map<String, dynamic>>().toList();
      }
      if (data.isEmpty) return null;
      data.shuffle();
      return data.first;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _rotating = true;
      _future = _load();
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _rotating = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final s = snap.data;
        if (s == null) return const SizedBox.shrink();
        final title = (s['title'] as String?) ?? '';
        final body = (s['body'] as String?) ?? '';
        final image = s['image_url'] as String?;
        final profileRaw = s['profiles'];
        Map<String, dynamic>? profile;
        if (profileRaw is Map<String, dynamic>) {
          profile = profileRaw;
        } else if (profileRaw is List && profileRaw.isNotEmpty) {
          final f = profileRaw.first;
          if (f is Map<String, dynamic>) profile = f;
        }
        final author = profile?['name'] as String?;
        final loc = profile?['location'] as String?;
        final excerpt = body.length > 180
            ? '${body.substring(0, 180).trimRight()}…'
            : body;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null && image.isNotEmpty)
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: image,
                    fadeInDuration: const Duration(milliseconds: 200),
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ShimmerBox(
                      width: double.infinity,
                      height: 140,
                      borderRadius: 0,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.elevated,
                      alignment: Alignment.center,
                      child: const Icon(LucideIcons.imageOff,
                          size: 20, color: AppColors.mute),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.bronze.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(LucideIcons.bookOpen,
                              size: 14, color: AppColors.bronze),
                        ),
                        const SizedBox(width: 8),
                        Text('home.successStory'.tr(),
                            style: AppTypography.label(
                                size: 9, color: AppColors.bronzeSoft)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'home.tooltipOtherStory'.tr(),
                          onPressed: _refresh,
                          icon: AnimatedRotation(
                            turns: _rotating ? 0.5 : 0,
                            duration: const Duration(milliseconds: 500),
                            child: const Icon(LucideIcons.refreshCw,
                                size: 14, color: AppColors.mute),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: FontWeight.w700,
                          height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '„$excerpt"',
                      style: AppTypography.body(
                          size: 12,
                          color: AppColors.inkSoft,
                          height: 1.5),
                    ),
                    if (author != null && author.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '— $author${loc != null && loc.isNotEmpty ? ', $loc' : ''}',
                        style: AppTypography.caption(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
