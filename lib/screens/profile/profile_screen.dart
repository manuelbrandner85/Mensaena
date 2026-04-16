import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/trust_score_badge.dart';
import 'package:mensaena/widgets/post_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final userId = ref.watch(currentUserIdProvider);
    final stats = userId != null ? ref.watch(profileStatsProvider(userId)) : null;
    final posts = userId != null ? ref.watch(userPostsProvider(userId)) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Profil'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/dashboard/profile/edit')),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (p) {
          if (p == null) return const Center(child: Text('Profil nicht gefunden'));
          return RefreshIndicator(
            onRefresh: () async { ref.invalidate(currentProfileProvider); },
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Center(child: AvatarWidget(imageUrl: p.avatarUrl, name: p.displayName, size: 80)),
              const SizedBox(height: 12),
              Center(child: Text(p.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
              if (p.bio != null) ...[const SizedBox(height: 8), Center(child: Text(p.bio!, style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center))],
              const SizedBox(height: 16),
              TrustScoreBadge(score: p.trustScore, size: TrustBadgeSize.large),
              const SizedBox(height: 16),
              if (stats != null) stats.when(
                data: (s) => Row(children: [
                  _StatCard(label: 'Beiträge', value: '${s['posts_count'] ?? 0}'),
                  const SizedBox(width: 8),
                  _StatCard(label: 'Geholfen', value: '${s['interactions_count'] ?? 0}'),
                  const SizedBox(width: 8),
                  _StatCard(label: 'Bewertungen', value: '${s['ratings_count'] ?? 0}'),
                ]),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              if (p.location != null) ListTile(leading: const Icon(Icons.location_on_outlined, color: AppColors.primary500), title: Text(p.location!), contentPadding: EdgeInsets.zero),
              if (p.skills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: p.skills.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 12)), backgroundColor: AppColors.primary50, side: BorderSide.none)).toList()),
              ],
              const SizedBox(height: 20),
              const Text('Meine Beiträge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (posts != null) posts.when(
                data: (list) => Column(children: list.take(10).map((post) => Padding(padding: const EdgeInsets.only(bottom: 12), child: PostCard(post: post, onTap: () => context.push('/dashboard/posts/${post.id}')))).toList()),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Fehler beim Laden'),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label; final String value;
  const _StatCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(children: [Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary500)), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))])));
  }
}