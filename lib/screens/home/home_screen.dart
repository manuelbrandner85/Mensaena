import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/dashboard_provider.dart';
import 'package:mensaena/providers/notification_provider.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/section_header.dart';
import 'package:mensaena/widgets/avatar_widget.dart';

const _dailyWhispers = [
  'Eine kleine Geste genügt, um jemandem den Tag zu retten.',
  'Nachbarschaft beginnt mit einem einzigen "Hallo".',
  'Wer teilt, verliert nichts — er gewinnt eine Verbindung.',
  'Heute ist ein guter Tag, um jemandem zuzuhören.',
  'Hilfe bekommt man am leichtesten, wenn man sie zuerst gibt.',
  'Du musst nicht die Welt retten. Nur einen Nachbarn.',
  'Freundlichkeit kostet nichts, zählt aber doppelt.',
  'Jede kleine Tat ist Teil eines größeren Mosaiks.',
];

String _getWhisper() {
  final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
  return _dailyWhispers[dayOfYear % _dailyWhispers.length];
}

({String text, String accent}) _getGreeting() {
  final h = DateTime.now().hour;
  if (h < 6) return (text: 'Gute', accent: 'Nacht');
  if (h < 12) return (text: 'Guten', accent: 'Morgen');
  if (h < 18) return (text: 'Guten', accent: 'Tag');
  if (h < 22) return (text: 'Guten', accent: 'Abend');
  return (text: 'Gute', accent: 'Nacht');
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _showScrollToTop = false;
  bool _ratingModalShown = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollCtrl.offset > 300;
    if (show != _showScrollToTop) setState(() => _showScrollToTop = show);
  }

  void _maybeShowRatingModal(List<dynamic> pending) {
    if (_ratingModalShown || pending.isEmpty || !mounted) return;
    _ratingModalShown = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final first = pending.first as Map<String, dynamic>;
      final postTitle = (first['posts'] is Map)
          ? (first['posts']['title'] as String? ?? 'Interaktion')
          : 'Interaktion';
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 40, color: AppColors.warning),
              const SizedBox(height: 12),
              Text('Bewerte "$postTitle"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Dein Feedback hilft der Gemeinschaft.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/dashboard/interactions/${first['id']}');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary500, foregroundColor: Colors.white),
                  child: const Text('Jetzt bewerten'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Später'),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final dashboardData = ref.watch(dashboardDataProvider);
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: AvatarWidget(
              imageUrl: profile.valueOrNull?.avatarUrl,
              name: profile.valueOrNull?.displayName ?? 'M',
              size: 32,
            ),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Image.asset('assets/images/icon-72x72.png', width: 40, height: 40),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${unreadNotifications.valueOrNull ?? 0}', style: const TextStyle(fontSize: 10)),
              isLabelVisible: (unreadNotifications.valueOrNull ?? 0) > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/dashboard/notifications'),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardDataProvider);
              ref.invalidate(currentProfileProvider);
            },
            color: AppColors.primary500,
            child: dashboardData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text('Fehler: $e', style: const TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => ref.invalidate(dashboardDataProvider), child: const Text('Erneut versuchen')),
                  ],
                ),
              ),
              data: (data) => _DashboardBody(
                data: data,
                profile: profile.valueOrNull,
                scrollController: _scrollCtrl,
                onPendingRatings: _maybeShowRatingModal,
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: AnimatedOpacity(
              opacity: _showScrollToTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showScrollToTop,
                child: FloatingActionButton.small(
                  onPressed: () => _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut),
                  backgroundColor: AppColors.primary500,
                  child: const Icon(Icons.arrow_upward, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final dynamic profile;
  final ScrollController? scrollController;
  final void Function(List<dynamic>)? onPendingRatings;
  const _DashboardBody({required this.data, this.profile, this.scrollController, this.onPendingRatings});

  @override
  Widget build(BuildContext context) {
    final stats = data['user_stats'] as Map<String, dynamic>? ?? {};
    final trustScore = data['trust_score'] as Map<String, dynamic>? ?? {};
    final pulse = data['community_pulse'] as Map<String, dynamic>? ?? {};
    final activity = (data['recent_activity'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final botTip = data['bot_tip'] as String?;
    final recentPosts = (data['recent_posts'] as List? ?? [])
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
    final greeting = _getGreeting();
    final whisper = _getWhisper();
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d. MMMM yyyy', 'de').format(now);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      children: [
        // 1. Hero Card
        _HeroCard(
          greeting: greeting,
          name: profile?.displayName ?? 'Nachbar',
          dateStr: dateStr,
          whisper: whisper,
          memberSinceDays: stats['member_since_days'] as int? ?? 0,
        ),
        const SizedBox(height: 12),

        // 2. Rating Prompt Banner
        _RatingPromptCard(onPendingRatings: onPendingRatings),

        // 3. Quick Actions (2x2 grid)
        _QuickActionsGrid(),
        const SizedBox(height: 12),

        // 4. Smart Match suggestions
        _SmartMatchWidget(),

        // 5. Onboarding Checklist (for new users)
        if (profile?.onboardingCompleted != true)
          _OnboardingChecklist(profile: profile),
        if (profile?.onboardingCompleted != true)
          const SizedBox(height: 12),

        // 6. Weekly Challenge Highlight
        _WeeklyChallengeCard(),
        const SizedBox(height: 12),

        // 7. Nearby Posts (horizontal carousel)
        SectionHeader(
          title: 'In deiner Nähe',
          actionLabel: 'Alle ansehen',
          onAction: () => context.push('/dashboard/posts'),
        ),
        const SizedBox(height: 8),

        if (recentPosts.isEmpty)
          _EmptyPostsBanner()
        else
          SizedBox(
            height: 180,
            child: Stack(
              children: [
                ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  itemCount: recentPosts.take(8).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _NearbyPostCard(post: recentPosts[i]),
                ),
                // Right fade gradient (like Web's bg-gradient-to-l from-background)
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.warmBg.withValues(alpha: 0), AppColors.warmBg],
                          begin: Alignment.centerLeft, end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // 8. Unread Messages
        _UnreadMessagesCard(),
        const SizedBox(height: 12),

        // 9. Stats Cards (2x2)
        _StatsGrid(stats: stats),
        const SizedBox(height: 12),

        // 10. Activity Feed
        _ActivityFeed(items: activity),

        // 11. Mini map
        _MiniMap(posts: recentPosts, profile: profile),
        const SizedBox(height: 12),

        // 12. Trust Score
        _TrustScoreCard(trustScore: trustScore),
        const SizedBox(height: 12),

        // 13. Community Pulse
        _CommunityPulseCard(pulse: pulse),
        const SizedBox(height: 12),

        // 14. Bot Tip
        _BotTipCard(tip: botTip),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ({String text, String accent}) greeting;
  final String name;
  final String dateStr;
  final String whisper;
  final int memberSinceDays;
  const _HeroCard({required this.greeting, required this.name, required this.dateStr, required this.whisper, required this.memberSinceDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1EAAA6), Color(0xFF147170)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary500.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          // Decorative circle (like web)
          Positioned(
            top: -30, left: -30,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.15), Colors.transparent]),
              ),
            ),
          ),
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: const TextStyle(fontSize: 12, color: Colors.white60, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          RichText(text: TextSpan(children: [
            TextSpan(text: '${greeting.text} ', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: Colors.white)),
            TextSpan(text: greeting.accent, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
            TextSpan(text: ', $name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: Colors.white)),
          ])),
          const SizedBox(height: 10),
          Text(
            '« $whisper »',
            style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.white70, height: 1.4),
          ),
          if (memberSinceDays > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(
                'Mitglied seit $memberSinceDays Tagen',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _GradientAction(
          icon: Icons.add_circle_outline,
          label: 'Beitrag erstellen',
          gradient: const [Color(0xFF1EAAA6), Color(0xFF178d8a)],
          onTap: () => context.push('/dashboard/create'),
        ),
        _GradientAction(
          icon: Icons.map_outlined,
          label: 'Karte öffnen',
          gradient: const [Color(0xFF38c4c0), Color(0xFF1EAAA6)],
          onTap: () => context.go('/dashboard/map'),
        ),
        _GradientAction(
          icon: Icons.chat_bubble_outline,
          label: 'Nachrichten',
          gradient: const [Color(0xFF4F6D8A), Color(0xFF3a5470)],
          onTap: () => context.go('/dashboard/messages'),
        ),
        _GradientAction(
          icon: Icons.search,
          label: 'Suche',
          gradient: const [Color(0xFF374151), Color(0xFF1f2937)],
          onTap: () => context.push('/dashboard/posts'),
        ),
      ],
    );
  }
}

class _GradientAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _GradientAction({required this.icon, required this.label, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: gradient[0].withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.3), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.favorite, label: 'Menschen geholfen', value: stats['people_helped'] ?? 0, color: const Color(0xFF1EAAA6)),
      (icon: Icons.article_outlined, label: 'Beiträge erstellt', value: stats['posts_count'] ?? 0, color: const Color(0xFF3B82F6)),
      (icon: Icons.handshake_outlined, label: 'Interaktionen', value: stats['interactions_count'] ?? 0, color: const Color(0xFF8B5CF6)),
      (icon: Icons.bookmark_outline, label: 'Gespeichert', value: stats['saved_count'] ?? 0, color: const Color(0xFFF59E0B)),
    ];

    final allZero = items.every((i) => (i.value as int) == 0);

    if (allZero) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Text('🌱', style: TextStyle(fontSize: 28)),
            SizedBox(height: 8),
            Text('Dein Abenteuer beginnt!', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Erstelle einen Beitrag oder hilf jemandem.', style: TextStyle(fontSize: 12, color: AppColors.textMuted), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: item.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(item.icon, size: 16, color: item.color),
            ),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: item.value as int),
              duration: const Duration(milliseconds: 900),
              builder: (_, val, __) => Text('$val', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
            Text(item.label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      )).toList(),
    );
  }
}

class _CommunityPulseCard extends StatelessWidget {
  final Map<String, dynamic> pulse;
  const _CommunityPulseCard({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final rows = [
      (icon: Icons.people_outline, label: 'Aktiv heute', value: pulse['active_users'] ?? 0),
      (icon: Icons.article_outlined, label: 'Neue Beiträge heute', value: pulse['new_posts'] ?? 0),
      (icon: Icons.handshake_outlined, label: 'Interaktionen diese Woche', value: pulse['interactions_week'] ?? 0),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 16, color: AppColors.primary500),
              const SizedBox(width: 6),
              const Text('Gemeinschafts-Puls', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              _PulseDot(),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(r.icon, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(r.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                Text('${r.value}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _TrustScoreCard extends StatelessWidget {
  final Map<String, dynamic> trustScore;
  const _TrustScoreCard({required this.trustScore});

  @override
  Widget build(BuildContext context) {
    final count = trustScore['count'] as int? ?? 0;
    final avg = (trustScore['average'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary500),
              const SizedBox(width: 6),
              const Text('Dein Vertrauen', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          if (count == 0)
            const Text('Noch keine Bewertungen. Hilf deinen Nachbarn!', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
          else
            Row(
              children: [
                Text(avg.toStringAsFixed(1), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(5, (i) => Icon(
                        i < avg.round() ? Icons.star : Icons.star_border,
                        size: 16, color: AppColors.warning,
                      )),
                    ),
                    Text('$count Bewertungen', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UnreadMessagesCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Ungelesene Nachrichten', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if ((unreadCount.valueOrNull ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                  child: Text('${unreadCount.valueOrNull}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.go('/dashboard/messages'),
                child: const Text('Alle →', style: TextStyle(fontSize: 12, color: AppColors.primary500, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if ((unreadCount.valueOrNull ?? 0) == 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 32, color: AppColors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(width: 12),
                const Text('Keine ungelesenen Nachrichten', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            )
          else
            GestureDetector(
              onTap: () => context.go('/dashboard/messages'),
              child: Row(
                children: [
                  const Icon(Icons.mail, size: 20, color: AppColors.primary500),
                  const SizedBox(width: 8),
                  Text('${unreadCount.valueOrNull} ungelesene Nachricht${(unreadCount.valueOrNull ?? 0) > 1 ? 'en' : ''}',
                    style: const TextStyle(fontSize: 13, color: AppColors.primary500, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Compact NearbyPost card — matches Web's NearbyPosts.tsx
// (272-310px min-width, 3px top accent, avatar + time + category)
class _NearbyPostCard extends StatelessWidget {
  final Post post;
  const _NearbyPostCard({required this.post});

  Color _typeAccent() {
    switch (post.postType) {
      case PostType.helpNeeded:
      case PostType.crisis:
        return AppColors.emergency;
      case PostType.helpOffered:
      case PostType.sharing:
        return AppColors.primary500;
      case PostType.animal:
        return const Color(0xFFF59E0B);
      case PostType.housing:
        return const Color(0xFF8B5CF6);
      case PostType.supply:
        return const Color(0xFF3B82F6);
      case PostType.mobility:
        return const Color(0xFF10B981);
      case PostType.community:
        return const Color(0xFF4F6D8A);
      case PostType.rescue:
        return const Color(0xFFEF4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _typeAccent();
    return GestureDetector(
      onTap: () => context.push('/dashboard/posts/${post.id}'),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          boxShadow: AppShadows.soft,
        ),
        child: Stack(
          children: [
            // Top accent line
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.27)],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                // Category + Time row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${post.postType.emoji} ${post.postType.label}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('d.M., HH:mm').format(post.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Title
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
                ),
                if (post.description != null && post.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    post.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                  ),
                ],
                const SizedBox(height: 10),
                // Divider
                Container(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 8),
                // Author row
                Row(
                  children: [
                    AvatarWidget(
                      imageUrl: post.authorAvatarUrl,
                      name: post.authorName,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ),
                    if (post.locationText != null && post.locationText!.isNotEmpty)
                      Text(
                        post.locationText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accent),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPostsBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.explore_outlined, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text('Noch keine Beiträge in deiner Nähe', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Erstelle den ersten Beitrag!', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/dashboard/create'),
            icon: const Icon(Icons.add),
            label: const Text('Beitrag erstellen'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingChecklist extends StatelessWidget {
  final dynamic profile;
  const _OnboardingChecklist({this.profile});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (label: 'Profil vervollständigen', done: profile?.bio != null && profile.bio.isNotEmpty, path: '/dashboard/profile/edit', icon: Icons.person),
      (label: 'Standort einstellen', done: profile?.location != null, path: '/dashboard/settings', icon: Icons.location_on),
      (label: 'Ersten Beitrag erstellen', done: false, path: '/dashboard/create', icon: Icons.add_circle),
      (label: 'Jemandem helfen', done: false, path: '/dashboard/posts', icon: Icons.volunteer_activism),
    ];
    final doneCount = steps.where((s) => s.done).length;
    final progress = doneCount / steps.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist, size: 18, color: AppColors.primary500),
              const SizedBox(width: 8),
              const Text('Erste Schritte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('$doneCount/${steps.length}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, backgroundColor: AppColors.border, valueColor: const AlwaysStoppedAnimation(AppColors.primary500), minHeight: 6),
          ),
          const SizedBox(height: 12),
          ...steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: s.done ? null : () => context.push(s.path),
              child: Row(
                children: [
                  Icon(s.done ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: s.done ? AppColors.success : AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(s.label, style: TextStyle(fontSize: 13, color: s.done ? AppColors.textMuted : AppColors.textSecondary, decoration: s.done ? TextDecoration.lineThrough : null)),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class _WeeklyChallengeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(supabaseProvider).from('challenges').select('id, title, description, category, points, participant_count, end_date').eq('status', 'active').eq('is_weekly', true).order('end_date').limit(1),
      builder: (context, snapshot) {
        if (!snapshot.hasData || (snapshot.data as List).isEmpty) return const SizedBox.shrink();
        final challenge = (snapshot.data as List).first;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Wochen-Challenge', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF92400E)))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text('+${challenge['points'] ?? 10} Pkt.', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(challenge['title'] as String? ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF78350F))),
              if (challenge['description'] != null) ...[
                const SizedBox(height: 4),
                Text(challenge['description'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 14, color: Color(0xFF92400E)),
                  const SizedBox(width: 4),
                  Text('${challenge['participant_count'] ?? 0} Teilnehmer', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E))),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/dashboard/challenges'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Mitmachen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Rating Prompt: zeigt offene Bewertungen nach abgeschlossenen Interaktionen
// ---------------------------------------------------------------------------
class _RatingPromptCard extends ConsumerWidget {
  final void Function(List<dynamic>)? onPendingRatings;
  const _RatingPromptCard({this.onPendingRatings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox.shrink();
    return FutureBuilder<List<dynamic>>(
      future: _loadUnrated(ref, userId),
      builder: (context, snap) {
        final pending = snap.data ?? const [];
        if (pending.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onPendingRatings?.call(pending);
          });
        }
        if (pending.isEmpty) return const SizedBox.shrink();
        final first = pending.first as Map<String, dynamic>;
        final postTitle = (first['posts'] is Map)
            ? (first['posts']['title'] as String? ?? 'Interaktion')
            : 'Interaktion';
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_outline, size: 18, color: Color(0xFF92400E)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Bewertung ausstehend',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                      ),
                    ),
                    if (pending.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${pending.length}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Bewerte "$postTitle" — deine Erfahrung hilft der Gemeinschaft.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => context.push('/dashboard/interactions/${first['id']}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(20)),
                      child: const Text('Jetzt bewerten', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<dynamic>> _loadUnrated(WidgetRef ref, String userId) async {
    try {
      final client = ref.read(supabaseProvider);
      final data = await client
          .from('interactions')
          .select('id, status, created_at, helper_id, user_id, post_id, posts(title)')
          .or('helper_id.eq.$userId,user_id.eq.$userId')
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(10);
      final list = (data as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return const [];
      final ratings = await client
          .from('trust_ratings')
          .select('interaction_id')
          .eq('rater_id', userId);
      final ratedIds = (ratings as List)
          .map((r) => r['interaction_id'])
          .whereType<String>()
          .toSet();
      return list.where((i) => !ratedIds.contains(i['id'])).toList();
    } catch (_) {
      return const [];
    }
  }
}

// ---------------------------------------------------------------------------
// Activity Feed: Zeigt die letzten Aktivitäten aus dashboard['recent_activity']
// ---------------------------------------------------------------------------
class _ActivityFeed extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ActivityFeed({required this.items});

  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'file_text':
        return Icons.description_outlined;
      case 'handshake':
        return Icons.handshake_outlined;
      case 'star':
        return Icons.star_outline;
      case 'clock':
        return Icons.access_time;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _colorFor(String? hex) {
    if (hex == null) return AppColors.primary500;
    final clean = hex.replaceFirst('#', '');
    final v = int.tryParse(clean, radix: 16);
    if (v == null) return AppColors.primary500;
    return Color(0xFF000000 | v);
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays < 7) return 'vor ${diff.inDays} T.';
    return DateFormat('d. MMM', 'de').format(d);
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final limited = items.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, size: 16, color: AppColors.primary500),
                const SizedBox(width: 6),
                const Text('Deine Aktivitäten', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/dashboard/profile'),
                  child: const Text('Alle →', style: TextStyle(fontSize: 12, color: AppColors.primary500, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...limited.map((a) {
              final color = _colorFor(a['color'] as String?);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Icon(_iconFor(a['icon'] as String?), size: 16, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['title'] as String? ?? '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if ((a['description'] as String?)?.isNotEmpty ?? false)
                            Text(
                              a['description'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _timeAgo(a['timestamp'] as String?),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini-Map: kompakte Karte mit Nachbar-Pins, tap -> /dashboard/map
// ---------------------------------------------------------------------------
class _MiniMap extends StatelessWidget {
  final List<Post> posts;
  final dynamic profile;
  const _MiniMap({required this.posts, this.profile});

  @override
  Widget build(BuildContext context) {
    final withCoords = posts.where((p) => p.latitude != null && p.longitude != null).toList();
    final lat = (profile?.latitude as double?) ?? (withCoords.isNotEmpty ? withCoords.first.latitude : 48.2082);
    final lng = (profile?.longitude as double?) ?? (withCoords.isNotEmpty ? withCoords.first.longitude : 16.3738);
    return GestureDetector(
      onTap: () => context.go('/dashboard/map'),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            AbsorbPointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat ?? 48.2082, lng ?? 16.3738),
                  initialZoom: 11,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'de.mensaena.app',
                  ),
                  MarkerLayer(
                    markers: withCoords.take(20).map((p) => Marker(
                      point: LatLng(p.latitude!, p.longitude!),
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 14),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12, top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, size: 14, color: AppColors.primary500),
                    SizedBox(width: 4),
                    Text('Karte öffnen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bot-Tipp: zeigt dashboard['bot_tip'] oder Fallback-Tipps
// ---------------------------------------------------------------------------
class _BotTipCard extends StatelessWidget {
  final String? tip;
  const _BotTipCard({this.tip});

  static const _fallbacks = [
    'Ein kurzes Hallo in der Nachbarschaft öffnet oft Türen.',
    'Teile, was du nicht brauchst — es hat woanders Zuhause.',
    'Wer hilft, erhält Vertrauen zurück.',
    'Vielleicht wartet heute jemand auf dein Angebot.',
  ];

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().day;
    final text = (tip != null && tip!.isNotEmpty) ? tip! : _fallbacks[day % _fallbacks.length];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE9FE), Color(0xFFDDD6FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.smart_toy_outlined, size: 18, color: Color(0xFF6D28D9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mensaena-Bot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6D28D9))),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF4C1D95), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Smart Match: ruft optionale RPC auf, fällt bei Fehler still weg
// ---------------------------------------------------------------------------
class _SmartMatchWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    if (profile == null) return const SizedBox.shrink();
    final seekTags = profile.seekTags;
    if (seekTags.isEmpty && profile.latitude == null) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(ref, profile),
      builder: (context, snap) {
        final matches = snap.data ?? const [];
        if (matches.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF065F46)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Für dich vorgeschlagen', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/dashboard/posts'),
                      child: const Text('Alle →', style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...matches.take(5).map((m) {
                  final title = (m['title'] ?? 'Vorschlag') as String;
                  final type = m['type'] as String? ?? '';
                  final authorName = (m['profiles'] is Map) ? (m['profiles']['name'] as String? ?? '') : '';
                  final postId = m['id'] as String?;
                  final emoji = _typeEmoji(type);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      onTap: postId == null ? null : () => context.push('/dashboard/posts/$postId'),
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                                if (authorName.isNotEmpty)
                                  Text(authorName, style: const TextStyle(fontSize: 11, color: Color(0xFF065F46))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _typeEmoji(String type) {
    switch (type) {
      case 'help_needed': return '🆘';
      case 'help_offered': return '🤝';
      case 'rescue': return '🚨';
      case 'animal': return '🐾';
      case 'housing': return '🏠';
      case 'supply': return '📦';
      case 'mobility': return '🚗';
      case 'sharing': return '🔄';
      case 'crisis': return '⚠️';
      case 'community': return '👥';
      default: return '📌';
    }
  }

  Future<List<Map<String, dynamic>>> _load(WidgetRef ref, dynamic profile) async {
    try {
      final client = ref.read(supabaseProvider);
      final lat = profile.latitude as double?;
      final lng = profile.longitude as double?;
      final radiusKm = profile.radiusKm as int? ?? 50;
      final seekTags = (profile.seekTags as List<String>?) ?? [];

      List<Map<String, dynamic>> posts;
      if (lat != null && lng != null) {
        final data = await client.rpc('get_nearby_posts', params: {
          'p_lat': lat, 'p_lng': lng, 'p_radius_km': radiusKm, 'p_limit': 20,
        });
        posts = List<Map<String, dynamic>>.from(data as List);
      } else {
        final data = await client.from('posts')
            .select('*, profiles(name, avatar_url)')
            .eq('status', 'active')
            .order('created_at', ascending: false)
            .limit(20);
        posts = List<Map<String, dynamic>>.from(data);
      }
      if (seekTags.isEmpty) return posts.take(5).toList();

      final seekSet = seekTags.map((t) => t.toLowerCase()).toSet();
      final matched = posts.where((p) {
        final tags = (p['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        return tags.any((t) => seekSet.contains(t.toLowerCase()));
      }).toList();
      if (matched.isNotEmpty) return matched.take(5).toList();
      return posts.take(5).toList();
    } catch (_) {
      return const [];
    }
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12, height: 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.6, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
            child: ScaleTransition(
              scale: Tween(begin: 1.0, end: 2.5).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
              child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary500, shape: BoxShape.circle)),
            ),
          ),
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary500, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}
