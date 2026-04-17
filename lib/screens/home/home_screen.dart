import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/dashboard_provider.dart';
import 'package:mensaena/providers/notification_provider.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/section_header.dart';
import 'package:mensaena/widgets/avatar_widget.dart';

const _dailyWhispers = [
  'Eine kleine Geste genuegt, um jemandem den Tag zu retten.',
  'Nachbarschaft beginnt mit einem einzigen "Hallo".',
  'Wer teilt, verliert nichts — er gewinnt eine Verbindung.',
  'Heute ist ein guter Tag, um jemandem zuzuhoeren.',
  'Hilfe bekommt man am leichtesten, wenn man sie zuerst gibt.',
  'Du musst nicht die Welt retten. Nur einen Nachbarn.',
  'Freundlichkeit kostet nichts, zaehlt aber doppelt.',
  'Jede kleine Tat ist Teil eines groesseren Mosaiks.',
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/icon-72x72.png', width: 28, height: 28),
            const SizedBox(width: 8),
            const Text('Mensaena'),
          ],
        ),
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
      body: RefreshIndicator(
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
          data: (data) => _DashboardBody(data: data, profile: profile.valueOrNull),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final dynamic profile;
  const _DashboardBody({required this.data, this.profile});

  @override
  Widget build(BuildContext context) {
    final stats = data['user_stats'] as Map<String, dynamic>? ?? {};
    final trustScore = data['trust_score'] as Map<String, dynamic>? ?? {};
    final pulse = data['community_pulse'] as Map<String, dynamic>? ?? {};
    final recentPosts = (data['recent_posts'] as List? ?? [])
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();
    final greeting = _getGreeting();
    final whisper = _getWhisper();
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d. MMMM yyyy', 'de').format(now);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Hero Card
        _HeroCard(
          greeting: greeting,
          name: profile?.displayName ?? 'Nachbar',
          dateStr: dateStr,
          whisper: whisper,
          memberSinceDays: stats['member_since_days'] as int? ?? 0,
        ),
        const SizedBox(height: 12),

        // Quick Actions (2x2 grid)
        _QuickActionsGrid(),
        const SizedBox(height: 12),

        // Onboarding Checklist (for new users)
        if (profile?.onboardingCompleted != true)
          _OnboardingChecklist(profile: profile),
        if (profile?.onboardingCompleted != true)
          const SizedBox(height: 12),

        // Weekly Challenge Highlight
        _WeeklyChallengeCard(),
        const SizedBox(height: 12),

        // Stats Cards (2x2)
        _StatsGrid(stats: stats),
        const SizedBox(height: 12),

        // Community Pulse
        _CommunityPulseCard(pulse: pulse),
        const SizedBox(height: 12),

        // Trust Score
        _TrustScoreCard(trustScore: trustScore),
        const SizedBox(height: 12),

        // Unread Messages
        _UnreadMessagesCard(),
        const SizedBox(height: 16),

        // Recent Posts
        SectionHeader(
          title: 'In deiner Naehe',
          actionLabel: 'Alle ansehen',
          onAction: () => context.push('/dashboard/posts'),
        ),
        const SizedBox(height: 8),

        if (recentPosts.isEmpty)
          _EmptyPostsBanner()
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: recentPosts.take(5).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final post = recentPosts[i];
                return SizedBox(
                  width: 280,
                  child: PostCard(
                    post: post,
                    showActions: false,
                    onTap: () => context.push('/dashboard/posts/${post.id}'),
                  ),
                );
              },
            ),
          ),

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
          label: 'Karte oeffnen',
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
      (icon: Icons.favorite, label: 'Menschen geholfen', value: stats['interactions_count'] ?? 0, color: const Color(0xFF1EAAA6)),
      (icon: Icons.article_outlined, label: 'Beitraege erstellt', value: stats['posts_count'] ?? 0, color: const Color(0xFF3B82F6)),
      (icon: Icons.handshake_outlined, label: 'Interaktionen', value: stats['completed_interactions'] ?? 0, color: const Color(0xFF8B5CF6)),
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
      (icon: Icons.article_outlined, label: 'Neue Beitraege heute', value: pulse['new_posts'] ?? 0),
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
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary500, shape: BoxShape.circle)),
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
          const Text('Noch keine Beitraege in deiner Naehe', style: TextStyle(fontWeight: FontWeight.w600)),
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
      (label: 'Profil vervollstaendigen', done: profile?.bio != null && profile.bio.isNotEmpty, path: '/dashboard/profile/edit', icon: Icons.person),
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
