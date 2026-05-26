/// SKILL: mensaena-features (F39 Post-Entwuerfe)
/// Zeigt alle posts.status='draft' des aktuellen Users mit Edit/Delete.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../services/supabase_service.dart';
import '../../widgets/effects/glass_card.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

final _draftsProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return const [];
  try {
    final rows = await sb
        .from('posts')
        .select()
        .eq('user_id', uid)
        .eq('status', 'draft')
        .order('updated_at', ascending: false)
        .limit(100);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(Post.fromJson)
        .toList();
  } catch (_) {
    return const [];
  }
});

class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_draftsProvider);
    return DashboardScaffold(
      title: 'posts.drafts'.tr(),
      currentRoute: '/dashboard/my-drafts',
      onRefresh: () async {
        ref.invalidate(_draftsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (drafts) {
          if (drafts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.fileText,
                        size: 32, color: AppColors.mute),
                    const SizedBox(height: 8),
                    Text('posts.no_drafts'.tr(),
                        style: AppTypography.caption()),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: drafts.length,
            itemBuilder: (_, i) {
              final d = drafts[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                    size: 14,
                                    color: AppColors.ink,
                                    weight: FontWeight.w700)),
                            if (d.description != null &&
                                d.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  d.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                      size: 12,
                                      color: AppColors.inkSoft,
                                      height: 1.4),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'common.edit'.tr(),
                        onPressed: () =>
                            context.push('/dashboard/posts/${d.id}'),
                        icon: const Icon(LucideIcons.edit2, size: 16),
                      ),
                      IconButton(
                        tooltip: 'common.delete'.tr(),
                        onPressed: () async {
                          await sb
                              .from('posts')
                              .delete()
                              .eq('id', d.id);
                          ref.invalidate(_draftsProvider);
                        },
                        icon: const Icon(LucideIcons.trash2,
                            size: 16, color: AppColors.herzrotWarm),
                      ),
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
