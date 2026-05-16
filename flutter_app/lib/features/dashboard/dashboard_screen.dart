import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/transitions/cascade_animation.dart';
import '../../core/widgets/cinema_app_shell.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_stat.dart';
import '../../core/widgets/kategorie_chip.dart';
import '../../core/widgets/nachbarschaft_card.dart';
import '../../providers/user_provider.dart';
import 'providers/dashboard_providers.dart';
import 'widgets/greeting_header.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentDisplayNameProvider);
    final feed = ref.watch(dashboardFeedProvider);
    final stats = ref.watch(dashboardStatsProvider);

    // isCrisis wird vom CinemaAppShell intern beobachtet (Atmosphaere-Shift).
    return CinemaAppShell(
      currentRoute: '/dashboard',
      title: 'DASHBOARD',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardFeedProvider),
        color: MnColors.amber,
        backgroundColor: MnColors.elevated,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(child: GreetingHeader(name: name)),
            SliverToBoxAdapter(child: _StatsRow(stats: stats)),
            const SliverToBoxAdapter(child: _QuickAccess()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            feed.when(
              loading: () => const SliverToBoxAdapter(
                child: CinemaLoadingSkeleton(variant: SkeletonVariant.list),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: CinemaEmptyState(
                  icon: LucideIcons.alertCircle,
                  title: 'Feed konnte nicht geladen werden.',
                  message: e.toString(),
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: CinemaEmptyState(
                      icon: LucideIcons.users,
                      title: 'Noch keine Beitraege in deiner Naehe.',
                      message: 'Sei die*der Erste — teile, was deine Nachbarschaft bewegt.',
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: posts.length,
                  itemBuilder: (_, i) => CascadeFadeInUp(
                    index: i.clamp(0, 8),
                    child: _PostTile(post: posts[i]),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

}

class _StatsRow extends StatelessWidget {
  final AsyncValue<DashboardStats> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats.asData?.value ?? const DashboardStats();
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          CinemaStat(
            value: s.activeNeighbors,
            label: 'Aktive Nachbarn',
            icon: LucideIcons.users,
          ),
          const SizedBox(width: 12),
          CinemaStat(
            value: s.helpOffers,
            label: 'Hilfsangebote',
            icon: LucideIcons.heart,
          ),
          const SizedBox(width: 12),
          CinemaStat(
            value: s.interactions,
            label: 'Interaktionen',
            icon: LucideIcons.messageCircle,
          ),
          const SizedBox(width: 12),
          CinemaStat(
            value: s.regions,
            label: 'Nachbarschaften',
            icon: LucideIcons.mapPin,
          ),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schnellzugriffe', style: MnTypography.label(color: MnColors.mute)),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: PostKategorie.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final kat = PostKategorie.values[i];
                return KategorieChip(
                  kategorie: kat,
                  onTap: () => GoRouter.of(ctx).push(
                    '/posts/new?category=${kat.name}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = (post['profiles'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final kategorie = _parseKategorie(post['type'] as String?);
    return NachbarschaftCard(
      kategorie: kategorie,
      authorName: author['full_name'] as String?,
      authorAvatarUrl: author['avatar_url'] as String?,
      timeAgo: _timeAgo(post['created_at'] as String?),
      content: (post['content'] as String?) ?? '',
      imageUrl: post['image_url'] as String?,
      likeCount: (post['like_count'] as int?) ?? 0,
      commentCount: (post['comment_count'] as int?) ?? 0,
      onTap: () => GoRouter.of(context).push('/posts/${post['id']}'),
    );
  }

  PostKategorie? _parseKategorie(String? type) {
    if (type == null) return null;
    return PostKategorie.values.where((k) => k.name == type).firstOrNull;
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tg.';
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}
