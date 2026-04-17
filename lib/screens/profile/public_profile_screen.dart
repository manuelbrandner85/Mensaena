import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/trust_score_badge.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(userId));
    final statsAsync = ref.watch(profileStatsProvider(userId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text('Fehler: $e'))),
        data: (p) {
          if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Profil nicht gefunden')));

          return CustomScrollView(
            slivers: [
              // Gradient banner with avatar
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 160,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primary500, AppColors.primary700], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
                    ),
                    if (currentUserId != null && currentUserId != userId)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        right: 8,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (v) async {
                            if (v == 'message') {
                              final chatService = ref.read(supabaseProvider);
                              try {
                                // Navigate to messages for now
                                context.push('/dashboard/messages');
                              } catch (_) {}
                            } else if (v == 'block') {
                              await ref.read(profileServiceProvider).blockUser(currentUserId, userId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nutzer blockiert')));
                                context.pop();
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'message', child: Row(children: [Icon(Icons.chat_bubble_outline, size: 18), SizedBox(width: 8), Text('Nachricht')])),
                            PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block, size: 18, color: AppColors.error), SizedBox(width: 8), Text('Blockieren', style: TextStyle(color: AppColors.error))])),
                          ],
                        ),
                      ),
                    Positioned(
                      bottom: -48,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.primary500.withValues(alpha: 0.3), blurRadius: 16)],
                          ),
                          child: AvatarWidget(imageUrl: p.avatarUrl, name: p.displayName, size: 96),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
                  child: Column(
                    children: [
                      Text(p.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      if (p.nickname != null)
                        Text('@${p.nickname}', style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      TrustScoreBadge(score: p.trustScore, size: TrustBadgeSize.large),
                      const SizedBox(height: 12),

                      // Meta row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (p.location != null) ...[
                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(p.location!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(width: 16),
                          ],
                          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text('Mitglied seit ${DateFormat('MMM yyyy', 'de').format(p.createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),

                      if (p.bio != null && p.bio!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(p.bio!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5), textAlign: TextAlign.center),
                      ],

                      // Offer/Seek tags
                      if (p.offerTags.isNotEmpty || p.seekTags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        if (p.offerTags.isNotEmpty) ...[
                          const Text('Bietet an', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, runSpacing: 4, children: p.offerTags.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.success)),
                          )).toList()),
                        ],
                        if (p.seekTags.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Sucht', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.info)),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, runSpacing: 4, children: p.seekTags.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.info)),
                          )).toList()),
                        ],
                      ],

                      // Skills
                      if (p.skills.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Align(alignment: Alignment.centerLeft, child: Text('Faehigkeiten', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: p.skills.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 12)), backgroundColor: AppColors.primary50, side: BorderSide.none)).toList()),
                      ],

                      const SizedBox(height: 20),

                      // Stats
                      statsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (stats) => Row(
                          children: [
                            _StatCard(value: '${stats['posts_count'] ?? 0}', label: 'Beitraege', color: AppColors.info),
                            const SizedBox(width: 8),
                            _StatCard(value: '${stats['interactions_count'] ?? 0}', label: 'Geholfen', color: AppColors.primary500),
                            const SizedBox(width: 8),
                            _StatCard(value: '${stats['hours_given'] ?? 0}h', label: 'Stunden', color: AppColors.trust),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action buttons
                      if (currentUserId != null && currentUserId != userId) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/dashboard/messages'),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Nachricht schreiben'),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
