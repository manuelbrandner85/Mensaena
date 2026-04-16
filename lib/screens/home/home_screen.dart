import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/dashboard_provider.dart';
import 'package:mensaena/providers/notification_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/section_header.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/trust_score_badge.dart';

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
          builder: (context) => IconButton(
            icon: AvatarWidget(
              imageUrl: profile.valueOrNull?.avatarUrl,
              name: profile.valueOrNull?.displayName ?? 'M',
              size: 32,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Mensaena'),
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
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (data) => _buildDashboard(context, ref, data, profile.valueOrNull),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, Map<String, dynamic> data, dynamic profile) {
    final stats = data['user_stats'] as Map<String, dynamic>? ?? {};
    final trustScore = data['trust_score'] as Map<String, dynamic>? ?? {};
    final recentPosts = (data['recent_posts'] as List? ?? [])
        .map((e) => Post.fromJson(e as Map<String, dynamic>))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary500, AppColors.primary700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.glow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hallo, ${profile?.displayName ?? 'Nachbar'}!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Schön, dass du da bist. Deine Nachbarschaft braucht dich.',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatChip(label: 'Beiträge', value: '${stats['posts_count'] ?? 0}'),
                  const SizedBox(width: 12),
                  _StatChip(label: 'Geholfen', value: '${stats['interactions_count'] ?? 0}'),
                  const SizedBox(width: 12),
                  _StatChip(label: 'Gemerkt', value: '${stats['saved_count'] ?? 0}'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Quick Actions
        SectionHeader(title: 'Schnellaktionen', icon: Icons.flash_on),
        const SizedBox(height: 8),
        Row(
          children: [
            _QuickAction(icon: Icons.add_circle_outline, label: 'Beitrag', color: AppColors.primary500, onTap: () => context.push('/dashboard/create')),
            const SizedBox(width: 12),
            _QuickAction(icon: Icons.map_outlined, label: 'Karte', color: AppColors.info, onTap: () => context.go('/dashboard/map')),
            const SizedBox(width: 12),
            _QuickAction(icon: Icons.warning_outlined, label: 'SOS', color: AppColors.emergency, onTap: () => context.push('/dashboard/crisis')),
            const SizedBox(width: 12),
            _QuickAction(icon: Icons.search, label: 'Suchen', color: AppColors.trust, onTap: () => context.push('/dashboard/posts')),
          ],
        ),

        const SizedBox(height: 20),

        // Trust Score
        if ((trustScore['count'] as int? ?? 0) > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                TrustScoreBadge(
                  score: ((trustScore['average'] as num?)?.toDouble() ?? 0) * 20,
                  size: TrustBadgeSize.large,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dein Vertrauensscore', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '${trustScore['count']} Bewertungen',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Recent Posts
        SectionHeader(
          title: 'Aktuelle Beiträge',
          actionLabel: 'Alle ansehen',
          onAction: () => context.push('/dashboard/posts'),
        ),
        const SizedBox(height: 8),

        ...recentPosts.take(5).map((post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                post: post,
                onTap: () => context.push('/dashboard/posts/${post.id}'),
              ),
            )),

        if (recentPosts.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
                SizedBox(height: 12),
                Text('Noch keine Beiträge', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  'Erstelle den ersten Beitrag in deiner Nachbarschaft!',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        const SizedBox(height: 32),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
