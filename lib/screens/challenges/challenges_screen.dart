import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/challenge_provider.dart';
import 'package:mensaena/models/challenge.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(challengesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenges'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(challengesProvider),
        color: AppColors.primary500,
        child: challengesAsync.when(
          loading: () => const LoadingSkeleton(type: SkeletonType.card),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (challenges) {
            if (challenges.isEmpty) {
              return const EmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'Keine Challenges',
                message: 'Aktuell gibt es keine aktiven Challenges.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: challenges.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ChallengeCard(challenge: challenges[index]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final Challenge challenge;
  const _ChallengeCard({required this.challenge});

  Color _getDifficultyColor() {
    switch (challenge.difficulty) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'hard':
        return AppColors.emergency;
      default:
        return AppColors.info;
    }
  }

  String _getDifficultyLabel() {
    switch (challenge.difficulty) {
      case 'easy':
        return 'Leicht';
      case 'medium':
        return 'Mittel';
      case 'hard':
        return 'Schwer';
      default:
        return 'Mittel';
    }
  }

  @override
  Widget build(BuildContext context) {
    final diffColor = _getDifficultyColor();
    final dateFormat = DateFormat('dd.MM.yyyy', 'de');
    final daysLeft = challenge.endDate.difference(DateTime.now()).inDays;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header gradient
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary500, AppColors.primary700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${challenge.points} Punkte',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getDifficultyLabel(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: diffColor),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (challenge.description != null) ...[
                  Text(
                    challenge.description!,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],

                // Progress
                if (challenge.userProgress != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: challenge.progressPercent,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(challenge.progressPercent * 100).round()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Streak
                if (challenge.userStreak != null && challenge.userStreak! > 0) ...[
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, size: 16, color: Color(0xFFFF6B35)),
                      const SizedBox(width: 4),
                      Text(
                        '${challenge.userStreak} Tage Streak',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF6B35)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Info row
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${dateFormat.format(challenge.startDate)} - ${dateFormat.format(challenge.endDate)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    if (daysLeft > 0)
                      Text(
                        'Noch $daysLeft Tage',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary500, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${challenge.participantCount ?? 0} Teilnehmer',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Check-in button
                if (challenge.isActive)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Check-in erfolgreich!')),
                        );
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Heute einchecken'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
