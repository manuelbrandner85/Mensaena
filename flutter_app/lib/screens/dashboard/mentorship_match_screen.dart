/// SKILL: mensaena-features (P10) — Mentor:innen finden.
/// Listet Profile mit is_mentor=true; ranked nach Topics-Überlap mit
/// eigenen Interessen (skills + preferred_modules).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/mega_repositories.dart';
import '../../services/supabase_service.dart';
import '../../widgets/effects/glass_card.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

class _MentorMatch {
  const _MentorMatch({
    required this.profile,
    required this.overlap,
    required this.topics,
  });
  final Map<String, dynamic> profile;
  final int overlap;
  final List<String> topics;
}

final _mentorMatchesProvider =
    FutureProvider.autoDispose<List<_MentorMatch>>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return const [];
  try {
    final me = await sb
        .from('profiles')
        .select('skills, preferred_modules, offer_tags, seek_tags')
        .eq('id', uid)
        .maybeSingle();
    final mine = <String>{
      ...((me?['skills'] as List?)?.whereType<String>() ?? const []),
      ...((me?['preferred_modules'] as List?)?.whereType<String>() ?? const []),
      ...((me?['offer_tags'] as List?)?.whereType<String>() ?? const []),
      ...((me?['seek_tags'] as List?)?.whereType<String>() ?? const []),
    }.map((s) => s.toLowerCase()).toSet();

    final rows = await sb
        .from('profiles')
        .select(
            'id, display_name, avatar_url, bio, mentor_topics, skills, location')
        .eq('is_mentor', true)
        .neq('id', uid)
        .limit(200);
    final matches = <_MentorMatch>[];
    for (final p in (rows as List).whereType<Map<String, dynamic>>()) {
      final topics = <String>{
        ...((p['mentor_topics'] as List?)?.whereType<String>() ?? const []),
        ...((p['skills'] as List?)?.whereType<String>() ?? const []),
      }.toList();
      final overlap = topics
          .where((t) => mine.contains(t.toLowerCase()))
          .length;
      matches.add(_MentorMatch(
          profile: p, overlap: overlap, topics: topics));
    }
    matches.sort((a, b) => b.overlap.compareTo(a.overlap));
    return matches.take(50).toList();
  } catch (_) {
    return const [];
  }
});

class MentorshipMatchScreen extends ConsumerWidget {
  const MentorshipMatchScreen({super.key});

  Future<void> _request(WidgetRef ref, String mentorId,
      BuildContext context) async {
    final ok = await MentorshipsRepository.request(mentorId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok
            ? 'mentorship.request_sent'.tr()
            : 'mentorship.request_failed'.tr(),
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_mentorMatchesProvider);
    return DashboardScaffold(
      title: 'mentorship.find_title'.tr(),
      currentRoute: '/dashboard/mentorship/find',
      onRefresh: () async {
        ref.invalidate(_mentorMatchesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.users,
                      size: 32, color: AppColors.mute),
                  const SizedBox(height: 8),
                  Text('mentorship.no_mentors'.tr(),
                      style: AppTypography.caption()),
                ]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final m = list[i];
              final p = m.profile;
              final name = (p['display_name'] as String?) ?? 'mensaena';
              final avatar = p['avatar_url'] as String?;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        ClipOval(
                          child: avatar != null
                              ? CachedNetworkImage(
                                  imageUrl: avatar,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  color: AppColors.elevated,
                                  alignment: Alignment.center,
                                  child: Text(name[0].toUpperCase(),
                                      style: AppTypography.body(
                                          size: 16,
                                          color: AppColors.ink,
                                          weight: FontWeight.w700)),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: AppTypography.body(
                                      size: 14,
                                      color: AppColors.ink,
                                      weight: FontWeight.w700)),
                              if (p['location'] != null)
                                Text(p['location'] as String,
                                    style: AppTypography.caption()),
                            ],
                          ),
                        ),
                        if (m.overlap > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.bronze
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: AppColors.bronze
                                      .withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              'mentorship.match_overlap'
                                  .tr(namedArgs: {'n': '${m.overlap}'}),
                              style: AppTypography.label(
                                  size: 9, color: AppColors.bronze),
                            ),
                          ),
                      ]),
                      if (p['bio'] != null &&
                          (p['bio'] as String).trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          p['bio'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                              size: 12,
                              color: AppColors.inkSoft,
                              height: 1.4),
                        ),
                      ],
                      if (m.topics.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: m.topics
                              .take(5)
                              .map((t) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.elevated,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(t,
                                        style: AppTypography.label(
                                            size: 9,
                                            color: AppColors.inkSoft)),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                _request(ref, p['id'] as String, context),
                            icon: const Icon(LucideIcons.heart, size: 14),
                            label: Text('mentorship.request'.tr()),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.bronze,
                                foregroundColor: AppColors.voidColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'common.openProfile'.tr(),
                          onPressed: () => context
                              .go('/dashboard/profile/${p['id']}'),
                          icon: const Icon(LucideIcons.arrowRight,
                              size: 18, color: AppColors.bronze),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
