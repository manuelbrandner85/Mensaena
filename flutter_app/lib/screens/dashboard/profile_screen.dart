import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import '../../repositories/challenges_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/post_card.dart';

/// SKILL: mensaena-features + mensaena-design
/// Profil-Screen: eigenes oder fremdes (per userId). Trust-Score + Level
/// + Bio + Standort + Skills + Actions.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.userId, super.key});

  /// null = eigenes Profil.
  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Future<Profile?>? _future;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _future = widget.userId == null
        ? ProfilesRepository.getMine()
        : ProfilesRepository.getById(widget.userId!);
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: widget.userId == null ? 'Mein Profil' : 'Profil',
      currentRoute: '/dashboard/profile',
      body: SafeArea(
        child: FutureBuilder<Profile?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.amber),
              );
            }
            final p = snap.data;
            if (p == null) {
              return Center(
                child: Text(
                  'Profil nicht gefunden.',
                  style: AppTypography.caption(),
                ),
              );
            }
            final isMe = widget.userId == null;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: _Header(profile: p),
                ),
                TabBar(
                  controller: _tab,
                  indicatorColor: AppColors.amber,
                  labelColor: AppColors.amber,
                  unselectedLabelColor: AppColors.inkSoft,
                  labelStyle: AppTypography.label(size: 11),
                  unselectedLabelStyle: AppTypography.label(size: 11),
                  tabs: const [
                    Tab(text: 'Über mich'),
                    Tab(text: 'Posts'),
                    Tab(text: 'Bewertungen'),
                    Tab(text: 'Badges'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _AboutTab(profile: p, isMe: isMe),
                      _PostsTab(userId: p.id),
                      _RatingsTab(userId: p.id),
                      _BadgesTab(userId: p.id),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.profile, required this.isMe});
  final Profile profile;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          Text('Über', style: AppTypography.label(size: 10)),
          const SizedBox(height: 6),
          Text(
            p.bio!,
            style: AppTypography.body(
              size: 14,
              color: AppColors.inkSoft,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
        ],
        _StatsGrid(profile: p),
        const SizedBox(height: 18),
        if (p.skills.isNotEmpty) ...[
          Text('Skills', style: AppTypography.label(size: 10)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: p.skills
                .map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s,
                        style: AppTypography.body(
                          size: 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 18),
        ],
        if (isMe) ...[
          OutlinedButton.icon(
            onPressed: () => context.go('/dashboard/settings'),
            icon: const Icon(LucideIcons.settings, size: 16),
            label: const Text('Einstellungen'),
          ),
        ],
      ],
    );
  }
}

class _PostsTab extends StatefulWidget {
  const _PostsTab({required this.userId});
  final String userId;

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  late Future<List<Post>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Post>> _load() async {
    try {
      final rows = await sb
          .from('posts')
          .select()
          .eq('author_id', widget.userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Post>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          );
        }
        final list = snap.data ?? const <Post>[];
        if (list.isEmpty) {
          return Center(
            child: Text('Noch keine Posts.',
                style: AppTypography.caption()),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, i) => PostCard(post: list[i]),
        );
      },
    );
  }
}

class _RatingsTab extends StatefulWidget {
  const _RatingsTab({required this.userId});
  final String userId;

  @override
  State<_RatingsTab> createState() => _RatingsTabState();
}

class _RatingsTabState extends State<_RatingsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final rows = await sb
          .from('trust_ratings')
          .select()
          .eq('rated_user_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          );
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return Center(
            child: Text('Noch keine Bewertungen.',
                style: AppTypography.caption()),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final r = list[i];
            final stars = (r['stars'] as num?)?.toInt() ?? 0;
            final comment = r['comment'] as String?;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var s = 0; s < 5; s++)
                        Icon(LucideIcons.star,
                            size: 14,
                            color: s < stars
                                ? AppColors.amber
                                : AppColors.mute),
                    ],
                  ),
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(comment,
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.inkSoft,
                            height: 1.4)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BadgesTab extends ConsumerWidget {
  const _BadgesTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mineAsync = ref.watch(myBadgesProvider);
    final allAsync = ref.watch(allBadgesProvider);
    return mineAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.amber),
      ),
      error: (_, __) => Center(
        child: Text('Fehler beim Laden.', style: AppTypography.caption()),
      ),
      data: (mine) {
        if (mine.isEmpty) {
          return Center(
            child: Text('Noch keine Badges erworben.',
                style: AppTypography.caption()),
          );
        }
        final allBadges = allAsync.value ?? const [];
        final earnedIds = <String>{for (final ub in mine) ub.badgeId};
        final earned = allBadges.where((b) => earnedIds.contains(b.id));
        return GridView(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          children: [
            for (final b in earned)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.10),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.award,
                        color: AppColors.amber, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      b.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                          size: 11,
                          color: AppColors.ink,
                          weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.surface,
          backgroundImage: profile.avatarUrl != null
              ? NetworkImage(profile.avatarUrl!)
              : null,
          child: profile.avatarUrl == null
              ? Text(
                  (profile.name ?? '?').substring(0, 1).toUpperCase(),
                  style: AppTypography.display(
                    size: 28,
                    color: AppColors.amber,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName ?? profile.name ?? 'Nachbar:in',
                style: AppTypography.display(
                  size: 22,
                  color: AppColors.ink,
                ),
              ),
              if (profile.location != null)
                Text(
                  profile.location!,
                  style: AppTypography.body(size: 13, color: AppColors.mute),
                ),
              const SizedBox(height: 8),
              _TrustBadge(
                  score: profile.trustScore, count: profile.trustScoreCount),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.score, required this.count});
  final int score;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = score >= 4
        ? AppColors.trust
        : score >= 3
            ? AppColors.amber
            : AppColors.mute;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.star, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            'Trust $score · $count Bewertungen',
            style: AppTypography.label(size: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            icon: LucideIcons.zap,
            label: 'Impact',
            value: '${profile.impactScore}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            icon: LucideIcons.trophy,
            label: 'Punkte',
            value: '${profile.points}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            icon: LucideIcons.heart,
            label: 'Spenden',
            value: '${profile.donationCount}',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.amber),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.mono(size: 18)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.label(size: 9)),
        ],
      ),
    );
  }
}
