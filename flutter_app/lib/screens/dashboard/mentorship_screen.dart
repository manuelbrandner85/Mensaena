/// SKILL: mensaena-features (P10 F69) — Mentoring-Übersicht.
/// Zeigt aktive Mentorships (ich = Mentor:in ODER Mentee).
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/mega_providers.dart';
import '../../services/supabase_service.dart';
import '../../widgets/effects/glass_card.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

final _partnersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, List<String>>((ref, ids) async {
  if (ids.isEmpty) return const [];
  try {
    final rows = await sb
        .from('profiles')
        .select('id, display_name, avatar_url')
        .inFilter('id', ids);
    return (rows as List).whereType<Map<String, dynamic>>().toList();
  } catch (_) {
    return const [];
  }
});

class MentorshipScreen extends ConsumerWidget {
  const MentorshipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myMentorshipsProvider);
    final me = SupabaseService.currentUser?.id;
    return DashboardScaffold(
      title: 'mentorship.title'.tr(),
      currentRoute: '/dashboard/mentorship',
      onRefresh: () async {
        ref.invalidate(myMentorshipsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (list) {
          if (list.isEmpty || me == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.users,
                      size: 32, color: AppColors.mute),
                  const SizedBox(height: 8),
                  Text('mentorship.empty'.tr(),
                      style: AppTypography.caption()),
                ]),
              ),
            );
          }
          final partnerIds = list
              .map((m) => m.mentorId == me ? m.menteeId : m.mentorId)
              .toSet()
              .toList();
          final partners = ref.watch(_partnersProvider(partnerIds));
          return partners.maybeWhen(
            data: (profiles) {
              final map = {for (final p in profiles) p['id'] as String: p};
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final m = list[i];
                  final partnerId = m.mentorId == me ? m.menteeId : m.mentorId;
                  final p = map[partnerId];
                  final name =
                      (p?['display_name'] as String?) ?? 'mensaena';
                  final avatar = p?['avatar_url'] as String?;
                  final amMentor = m.mentorId == me;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        ClipOval(
                          child: avatar != null
                              ? CachedNetworkImage(
                                  imageUrl: avatar,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _avatarFallback(name),
                                )
                              : _avatarFallback(name),
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
                              Text(
                                amMentor
                                    ? 'mentorship.you_are_mentor'.tr()
                                    : 'mentorship.you_are_mentee'.tr(),
                                style: AppTypography.caption(),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'common.openProfile'.tr(),
                          onPressed: () => context
                              .go('/dashboard/profile/$partnerId'),
                          icon: const Icon(LucideIcons.arrowRight, size: 18),
                        ),
                      ]),
                    ),
                  );
                },
              );
            },
            orElse: () => const Center(
                child:
                    CircularProgressIndicator(color: AppColors.bronze)),
          );
        },
      ),
    );
  }

  Widget _avatarFallback(String name) => Container(
        width: 44,
        height: 44,
        color: AppColors.elevated,
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: AppTypography.display(size: 16, color: AppColors.ink),
        ),
      );
}
