import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/widgets/editorial_header.dart';
import 'package:mensaena/providers/matching_provider.dart';
import 'package:mensaena/models/match.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/badge_widget.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class MatchingScreen extends ConsumerWidget {
  const MatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final countsAsync = ref.watch(matchCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matching'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(matchesProvider);
          ref.invalidate(matchCountsProvider);
        },
        color: AppColors.primary500,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: EditorialHeader(
                section: 'MATCHING',
                number: '21',
                title: 'Smart Matching',
                subtitle: 'Passende Hilfsangebote',
                icon: Icons.auto_awesome,
              ),
            ),
            // Stats
            countsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (counts) => Row(
                children: [
                  _StatCard(label: 'Vorgeschlagen', value: '${counts['suggested'] ?? 0}', color: AppColors.info),
                  const SizedBox(width: 12),
                  _StatCard(label: 'Angenommen', value: '${counts['accepted'] ?? 0}', color: AppColors.success),
                  const SizedBox(width: 12),
                  _StatCard(label: 'Abgeschlossen', value: '${counts['completed'] ?? 0}', color: AppColors.primary500),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text('Vorschlaege', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            matchesAsync.when(
              loading: () => const LoadingSkeleton(type: SkeletonType.card),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (matches) {
                if (matches.isEmpty) {
                  return const EmptyState(
                    icon: Icons.handshake_outlined,
                    title: 'Keine Matches',
                    message: 'Erstelle einen Beitrag, um passende Matches zu finden!',
                  );
                }
                return Column(
                  children: matches.map((match) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MatchCard(
                          match: match,
                          onAccept: () async {
                            await ref.read(matchingServiceProvider).respondToMatch(match.id, true);
                            ref.invalidate(matchesProvider);
                            ref.invalidate(matchCountsProvider);
                          },
                          onDecline: () async {
                            await ref.read(matchingServiceProvider).respondToMatch(match.id, false);
                            ref.invalidate(matchesProvider);
                            ref.invalidate(matchCountsProvider);
                          },
                        ),
                      )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _MatchCard({required this.match, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final seekerName = match.seekerProfile?['nickname'] as String? ?? 'Unbekannt';
    final offerName = match.offerProfile?['nickname'] as String? ?? 'Unbekannt';
    final seekerPost = match.seekerPost;
    final offerPost = match.offerPost;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          // Score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      match.scorePercent > 70 ? AppColors.success : AppColors.primary500,
                      match.scorePercent > 70 ? const Color(0xFF047857) : AppColors.primary700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${match.scorePercent}% Match',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Seeker & Offer
          Row(
            children: [
              Expanded(
                child: _PersonInfo(
                  name: seekerName,
                  avatarUrl: match.seekerProfile?['avatar_url'] as String?,
                  postTitle: seekerPost?['title'] as String?,
                  label: 'Sucht',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.sync_alt, color: AppColors.primary500),
              ),
              Expanded(
                child: _PersonInfo(
                  name: offerName,
                  avatarUrl: match.offerProfile?['avatar_url'] as String?,
                  postTitle: offerPost?['title'] as String?,
                  label: 'Bietet',
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Status badge
          AppBadge(label: match.matchStatus.label, color: _getStatusColor(match.matchStatus)),

          const SizedBox(height: 12),

          // Actions
          if (match.status == 'suggested')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Ablehnen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('Annehmen'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(MatchStatus status) {
    switch (status) {
      case MatchStatus.suggested:
        return AppColors.info;
      case MatchStatus.accepted:
        return AppColors.success;
      case MatchStatus.declined:
        return AppColors.error;
      case MatchStatus.completed:
        return AppColors.primary500;
      default:
        return AppColors.textMuted;
    }
  }
}

class _PersonInfo extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? postTitle;
  final String label;
  const _PersonInfo({required this.name, this.avatarUrl, this.postTitle, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AvatarWidget(imageUrl: avatarUrl, name: name, size: 40),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        if (postTitle != null)
          Text(postTitle!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
