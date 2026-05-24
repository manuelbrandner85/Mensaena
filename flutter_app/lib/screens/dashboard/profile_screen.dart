import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import '../../repositories/challenges_repository.dart';
import '../../repositories/content_reports_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../repositories/trust_ratings_repository.dart';
import '../../repositories/user_blocks_repository.dart';
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
        _ProfileStatsBar(userId: p.id),
        const SizedBox(height: 18),
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

class _ProfileStatsBar extends StatefulWidget {
  const _ProfileStatsBar({required this.userId});
  final String userId;

  @override
  State<_ProfileStatsBar> createState() => _ProfileStatsBarState();
}

class _ProfileStatsBarState extends State<_ProfileStatsBar> {
  late Future<_StatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsData> _load() async {
    try {
      final results = await Future.wait([
        sb
            .from('posts')
            .select('id')
            .eq('user_id', widget.userId)
            .eq('status', 'active'),
        sb
            .from('group_members')
            .select('id')
            .eq('user_id', widget.userId),
        sb
            .from('challenge_progress')
            .select('id, completed')
            .eq('user_id', widget.userId),
        sb
            .from('timebank_entries')
            .select('hours, giver_id, receiver_id, status')
            .or('giver_id.eq.${widget.userId},receiver_id.eq.${widget.userId}')
            .eq('status', 'confirmed'),
      ]);
      double given = 0;
      double received = 0;
      for (final r in (results[3] as List).whereType<Map<String, dynamic>>()) {
        final h = (r['hours'] as num?)?.toDouble() ?? 0;
        if (r['giver_id'] == widget.userId) {
          given += h;
        } else {
          received += h;
        }
      }
      final activeCh = (results[2] as List)
          .whereType<Map<String, dynamic>>()
          .where((c) => c['completed'] != true)
          .length;
      return _StatsData(
        postsCount: (results[0] as List).length,
        groupsCount: (results[1] as List).length,
        activeChallenges: activeCh,
        hoursGiven: given,
        hoursReceived: received,
      );
    } catch (_) {
      return const _StatsData(
        postsCount: 0,
        groupsCount: 0,
        activeChallenges: 0,
        hoursGiven: 0,
        hoursReceived: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StatsData>(
      future: _future,
      builder: (context, snap) {
        final s = snap.data ??
            const _StatsData(
              postsCount: 0,
              groupsCount: 0,
              activeChallenges: 0,
              hoursGiven: 0,
              hoursReceived: 0,
            );
        final netto = (s.hoursGiven - s.hoursReceived);
        return Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: LucideIcons.clock,
                color: AppColors.bronze,
                value: '${netto.toStringAsFixed(1)}h',
                label: 'Zeitbank',
                sub: '${s.hoursGiven.toStringAsFixed(0)}h ↑ ${s.hoursReceived.toStringAsFixed(0)}h ↓',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatTile(
                icon: LucideIcons.users2,
                color: AppColors.tealSoft,
                value: '${s.groupsCount}',
                label: 'Gruppen',
                sub: s.groupsCount == 1
                    ? 'Mitgliedschaft'
                    : 'Mitgliedschaften',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatTile(
                icon: LucideIcons.trophy,
                color: AppColors.amber,
                value: '${s.activeChallenges}',
                label: 'Challenges',
                sub: 'aktiv',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatTile(
                icon: LucideIcons.fileText,
                color: AppColors.lebenSoft,
                value: '${s.postsCount}',
                label: 'Beiträge',
                sub: 'aktiv',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatsData {
  const _StatsData({
    required this.postsCount,
    required this.groupsCount,
    required this.activeChallenges,
    required this.hoursGiven,
    required this.hoursReceived,
  });
  final int postsCount;
  final int groupsCount;
  final int activeChallenges;
  final double hoursGiven;
  final double hoursReceived;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.sub,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.mono(
              size: 16,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            style: AppTypography.label(size: 8, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              size: 9,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
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
    final isMe = SupabaseService.currentUser?.id == profile.id;
    return Column(
      children: [
        Row(
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
                      style: AppTypography.body(
                          size: 13, color: AppColors.mute),
                    ),
                  const SizedBox(height: 8),
                  _TrustBadge(
                      score: profile.trustScore,
                      count: profile.trustScoreCount,
                      userId: profile.id),
                ],
              ),
            ),
          ],
        ),
        if (isMe) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/dashboard/profile/edit'),
                  icon: const Icon(LucideIcons.edit2, size: 14),
                  label: const Text('Profil bearbeiten'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bronze,
                    side: BorderSide(
                        color: AppColors.bronze.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/dashboard/profile/saved'),
                  icon: const Icon(LucideIcons.bookmark, size: 14),
                  label: const Text('Gespeichert'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: BorderSide(
                        color: AppColors.amber.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          _OtherUserActions(targetUserId: profile.id),
        ],
      ],
    );
  }
}

/// 3-Punkte-Menü für fremde Profile: Blockieren + Melden.
/// 1:1 zur Web-Implementierung in OtherUserProfile.tsx.
class _OtherUserActions extends StatefulWidget {
  const _OtherUserActions({required this.targetUserId});
  final String targetUserId;

  @override
  State<_OtherUserActions> createState() => _OtherUserActionsState();
}

class _OtherUserActionsState extends State<_OtherUserActions> {
  bool _busy = false;

  Future<void> _confirmBlock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Nutzer:in blockieren?',
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text(
            'Du wirst Beiträge und Nachrichten dieses Nutzers nicht mehr sehen.',
            style:
                AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: const Text('Blockieren'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final ok = await UserBlocksRepository.block(widget.targetUserId);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(ok ? 'Nutzer:in blockiert.' : 'Fehler beim Blockieren.',
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
  }

  Future<void> _showReportDialog() async {
    const reasons = <String>[
      'Spam',
      'Belästigung',
      'Hass / Diskriminierung',
      'Gewalt',
      'Falsche Informationen',
      'Anstößige Inhalte',
      'Anderer Grund',
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Nutzer:in melden',
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Wähle einen Grund:',
                style: AppTypography.body(
                    size: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 10),
            for (final r in reasons)
              ListTile(
                dense: true,
                title: Text(r,
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink)),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await ContentReportsRepository.report(
      contentType: 'user',
      contentId: widget.targetUserId,
      reason: selected,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok ? 'Meldung übermittelt. Danke.' : 'Meldung fehlgeschlagen.',
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _showReportDialog,
            icon: const Icon(LucideIcons.flag, size: 14),
            label: const Text('Melden'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.amber,
              side: BorderSide(
                  color: AppColors.amber.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _confirmBlock,
            icon: const Icon(LucideIcons.ban, size: 14),
            label: const Text('Blockieren'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.herzrot,
              side: BorderSide(
                  color: AppColors.herzrot.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.score,
    required this.count,
    required this.userId,
  });
  final int score;
  final int count;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final color = score >= 4
        ? AppColors.trust
        : score >= 3
            ? AppColors.amber
            : AppColors.mute;
    return InkWell(
      onTap: () => _showBreakdown(context),
      borderRadius: BorderRadius.circular(999),
      child: Container(
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
            const SizedBox(width: 4),
            Icon(LucideIcons.info, size: 10, color: color),
          ],
        ),
      ),
    );
  }

  void _showBreakdown(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TrustBreakdownSheet(userId: userId),
    );
  }
}

class _TrustBreakdownSheet extends StatefulWidget {
  const _TrustBreakdownSheet({required this.userId});
  final String userId;

  @override
  State<_TrustBreakdownSheet> createState() => _TrustBreakdownSheetState();
}

class _TrustBreakdownSheetState extends State<_TrustBreakdownSheet> {
  Future<Map<String, dynamic>?>? _future;

  @override
  void initState() {
    super.initState();
    _future = TrustRatingsRepository.getBreakdown(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final data = snap.data ?? const <String, dynamic>{};
        final avg = (data['avg_score'] as num?)?.toDouble() ??
            (data['average_score'] as num?)?.toDouble() ??
            0;
        final total = (data['total_ratings'] as int?) ?? 0;
        final dist = data['score_distribution'] as Map<String, dynamic>?;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(LucideIcons.shieldCheck,
                      size: 18, color: AppColors.trust),
                  const SizedBox(width: 8),
                  Text('Trust-Breakdown',
                      style: AppTypography.display(
                          size: 18, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 14),
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        color: AppColors.amber),
                  ),
                )
              else if (total == 0)
                Text(
                  'Noch keine Bewertungen für diesen Nutzer.',
                  style: AppTypography.body(
                      size: 13, color: AppColors.mute),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      avg.toStringAsFixed(1),
                      style: AppTypography.display(
                          size: 38, color: AppColors.amber),
                    ),
                    const SizedBox(width: 6),
                    Text('/ 5',
                        style: AppTypography.body(
                            size: 14, color: AppColors.mute)),
                    const SizedBox(width: 12),
                    Text('aus $total Bewertungen',
                        style: AppTypography.body(
                            size: 12, color: AppColors.inkSoft)),
                  ],
                ),
                const SizedBox(height: 16),
                if (dist != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [5, 4, 3, 2, 1].map((star) {
                      final count = (dist['$star'] as int?) ?? 0;
                      final pct = total > 0 ? count / total : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Row(
                                children: [
                                  Text('$star',
                                      style: AppTypography.body(
                                          size: 12,
                                          color: AppColors.inkSoft)),
                                  const SizedBox(width: 2),
                                  const Icon(LucideIcons.star,
                                      size: 10,
                                      color: AppColors.amber),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: AppColors.elevated,
                                  valueColor:
                                      const AlwaysStoppedAnimation(
                                          AppColors.amber),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 32,
                              child: Text('$count',
                                  textAlign: TextAlign.end,
                                  style: AppTypography.mono(
                                      size: 11,
                                      color: AppColors.mute)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Trust-Score wird automatisch berechnet aus allen abgeschlossenen Interaktionen.',
                  style: AppTypography.body(
                      size: 11, color: AppColors.mute, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
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
