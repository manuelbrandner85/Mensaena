// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/cinema_avatar.dart';
import '../../../core/widgets/cinema_stat.dart';
import '../../../core/widgets/nachbarschaft_card.dart';
import '../../../services/supabase/supabase_service.dart';
import '../providers/dashboard_data_provider.dart';

// ─────────────────────────────────────────────────────────────────────
//  1. DashboardHeroCard
//     1:1 zu /src/app/dashboard/components/DashboardHeroCard
// ─────────────────────────────────────────────────────────────────────
class DashboardHeroCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final int memberSinceDays;

  const DashboardHeroCard({
    super.key,
    this.profile,
    required this.memberSinceDays,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h <= 11) return 'Guten Morgen';
    if (h >= 12 && h <= 17) return 'Schoenen Tag';
    if (h >= 18 && h <= 21) return 'Guten Abend';
    return 'Gute Nacht';
  }

  @override
  Widget build(BuildContext context) {
    final name = (profile?['full_name'] as String?)?.trim();
    final displayName = (name == null || name.isEmpty) ? 'Nachbar*in' : name;
    final bio = (profile?['bio'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MnColors.surface,
            MnColors.elevated.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.amber.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CinemaAvatar(
            imageUrl: profile?['avatar_url'] as String?,
            displayName: displayName,
            size: AvatarSize.lg,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting,
                  style: MnTypography.label(color: MnColors.amber),
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: MnTypography.display(size: 24),
                ),
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    bio,
                    style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 12, color: MnColors.mute),
                    const SizedBox(width: 4),
                    Text(
                      'Mitglied seit $memberSinceDays Tagen',
                      style: MnTypography.mono(size: 11, color: MnColors.mute),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  2. NinaWarningBanner & FoodWarningBanner (vereinfacht)
//     1:1 zu /src/components/dashboard/NinaWarningBanner
// ─────────────────────────────────────────────────────────────────────
class NinaWarningBanner extends ConsumerWidget {
  const NinaWarningBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reactivity: lese 'warnings' Tabelle wenn vorhanden, sonst leer.
    // Fuer Echtzeit-Daten: zukuenftig NINA-API via Edge-Function.
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────
//  3. OnboardingChecklist
//     1:1 zu /src/app/dashboard/components/OnboardingChecklist
// ─────────────────────────────────────────────────────────────────────
class OnboardingChecklist extends StatelessWidget {
  final OnboardingProgress progress;

  const OnboardingChecklist({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress.completed) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.amber.withValues(alpha: 0.06),
        border: Border.all(color: MnColors.amber.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.checkCircle2, size: 16, color: MnColors.amber),
              const SizedBox(width: 8),
              Text(
                'Profil vervollstaendigen',
                style: MnTypography.body(
                  color: MnColors.ink,
                  weight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${progress.completedSteps}/${progress.totalSteps}',
                style: MnTypography.mono(color: MnColors.amber, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 6,
              backgroundColor: MnColors.surface,
              valueColor: const AlwaysStoppedAnimation(MnColors.amber),
            ),
          ),
          if (progress.missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...progress.missing.take(3).map(
              (step) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.circle,
                      size: 12,
                      color: MnColors.mute,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      step,
                      style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  4. QuickActions — 4-6 haeufige Aktionen
//     1:1 zu /src/app/dashboard/components/QuickActions
// ─────────────────────────────────────────────────────────────────────
class QuickActions extends StatelessWidget {
  final int unreadCount;
  const QuickActions({super.key, this.unreadCount = 0});

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: LucideIcons.plusCircle,
        label: 'Beitrag erstellen',
        route: '/posts/new',
        accent: MnColors.amber,
      ),
      _QuickAction(
        icon: LucideIcons.map,
        label: 'Karte',
        route: '/map',
        accent: MnColors.teal,
      ),
      _QuickAction(
        icon: LucideIcons.mail,
        label: 'Nachrichten',
        route: '/messages',
        accent: MnColors.tealSoft,
        badge: unreadCount,
      ),
      _QuickAction(
        icon: LucideIcons.alertTriangle,
        label: 'Krise melden',
        route: '/crisis',
        accent: MnColors.herzrot,
      ),
      _QuickAction(
        icon: LucideIcons.users,
        label: 'Gruppen',
        route: '/modules/gruppen',
        accent: MnColors.amberSoft,
      ),
      _QuickAction(
        icon: LucideIcons.calendar,
        label: 'Events',
        route: '/modules/events',
        accent: MnColors.amberWarm,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Schnellzugriff', style: MnTypography.label(color: MnColors.mute)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: actions
                .map((a) => _QuickActionTile(action: a))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String route;
  final Color accent;
  final int badge;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.route,
    required this.accent,
    this.badge = 0,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(MnDimensions.radiusButton),
      onTap: () => GoRouter.of(context).push(action.route),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: action.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(MnDimensions.radiusButton),
          border: Border.all(color: action.accent.withValues(alpha: 0.20)),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(action.icon, size: 22, color: action.accent),
                if (action.badge > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: const BoxDecoration(
                        color: MnColors.herzrot,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        action.badge > 99 ? '99+' : action.badge.toString(),
                        style: MnTypography.mono(
                          size: 10,
                          color: MnColors.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: MnTypography.body(
                color: MnColors.inkSoft,
                size: 11,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  5. UnreadMessages
//     1:1 zu /src/app/dashboard/components/UnreadMessages
// ─────────────────────────────────────────────────────────────────────
class UnreadMessagesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  const UnreadMessagesWidget({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.mail, size: 16, color: MnColors.amber),
              const SizedBox(width: 8),
              Text(
                'Ungelesene Nachrichten',
                style: MnTypography.label(color: MnColors.mute),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: MnColors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${messages.length}',
                  style: MnTypography.mono(
                    size: 11,
                    color: MnColors.amber,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...messages.take(3).map((m) {
            final content = (m['content'] as String?) ?? '';
            final convId = m['conversation_id'] as String?;
            return InkWell(
              onTap: convId == null
                  ? null
                  : () => GoRouter.of(context).push('/chat/$convId'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const CinemaAvatar(size: AvatarSize.sm),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MnTypography.body(
                          color: MnColors.inkSoft,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  6. SmartMatchWidget — KI-Matching
//     1:1 zu /src/components/dashboard/SmartMatchWidget
// ─────────────────────────────────────────────────────────────────────
class SmartMatchWidget extends StatelessWidget {
  const SmartMatchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
      onTap: () => GoRouter.of(context).push('/matching'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MnColors.amber.withValues(alpha: 0.10),
              MnColors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          border: Border.all(color: MnColors.amber.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MnColors.amber.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.sparkles, color: MnColors.amber),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KI-Matching',
                    style: MnTypography.body(
                      color: MnColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Personalisierte Beitraege fuer dich',
                    style: MnTypography.body(color: MnColors.inkSoft, size: 12),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: MnColors.mute),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  7. NearbyPosts
//     1:1 zu /src/app/dashboard/components/NearbyPosts
// ─────────────────────────────────────────────────────────────────────
class NearbyPostsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool hasCoords;
  const NearbyPostsWidget({
    super.key,
    required this.posts,
    required this.hasCoords,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text(
                'Beitraege in deiner Naehe',
                style: MnTypography.display(size: 18),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => GoRouter.of(context).push('/map'),
                child: Text(
                  'Auf Karte',
                  style: MnTypography.body(color: MnColors.amber, size: 13),
                ),
              ),
            ],
          ),
        ),
        if (posts.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: MnColors.surface,
              borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
              border: Border.all(color: MnColors.line),
            ),
            child: Center(
              child: Text(
                hasCoords
                    ? 'Noch keine Beitraege in deiner Naehe.'
                    : 'Aktiviere deinen Standort, um lokale Beitraege zu sehen.',
                style: MnTypography.body(color: MnColors.mute),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...posts.take(5).map((p) {
            final author = (p['profiles'] as Map<String, dynamic>?) ?? const {};
            final kat = PostKategorie.values
                .where((k) => k.name == (p['type'] as String?))
                .firstOrNull;
            return NachbarschaftCard(
              kategorie: kat,
              authorName: author['full_name'] as String?,
              authorAvatarUrl: author['avatar_url'] as String?,
              timeAgo: (p['created_at'] as String?) ?? '',
              content: (p['content'] as String?) ?? '',
              imageUrl: p['image_url'] as String?,
              onTap: () => GoRouter.of(context).push('/posts/${p['id']}'),
            );
          }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  8. WeeklyChallengeHighlight
//     1:1 zu /src/components/features/WeeklyChallengeHighlight
// ─────────────────────────────────────────────────────────────────────
class WeeklyChallengeHighlight extends StatelessWidget {
  const WeeklyChallengeHighlight({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
      onTap: () => GoRouter.of(context).push('/modules/challenges'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MnColors.amberWarm.withValues(alpha: 0.10),
              MnColors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          border: Border.all(color: MnColors.amberWarm.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MnColors.amberWarm.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.trophy, color: MnColors.amberWarm),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wochen-Challenge',
                    style: MnTypography.body(
                      color: MnColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Mach mit und sammle Punkte',
                    style: MnTypography.body(color: MnColors.inkSoft, size: 12),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: MnColors.mute),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  9. StatsCards — 4 Kennzahlen
//     1:1 zu /src/app/dashboard/components/StatsCards
// ─────────────────────────────────────────────────────────────────────
class StatsCards extends StatelessWidget {
  final DashboardStats stats;
  const StatsCards({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deine Mensaena-Zahlen',
            style: MnTypography.label(color: MnColors.mute),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              CinemaStat(
                value: stats.hoursGiven,
                label: 'Stunden gegeben',
                icon: LucideIcons.arrowUpRight,
                valueColor: MnColors.leben,
              ),
              CinemaStat(
                value: stats.hoursReceived,
                label: 'Stunden erhalten',
                icon: LucideIcons.arrowDownLeft,
                valueColor: MnColors.amber,
              ),
              CinemaStat(
                value: stats.groups,
                label: 'Gruppen',
                icon: LucideIcons.users,
              ),
              CinemaStat(
                value: stats.challenges,
                label: 'Challenges',
                icon: LucideIcons.trophy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  10. TrustScoreCard
//      1:1 zu /src/app/dashboard/components/TrustScoreCard
// ─────────────────────────────────────────────────────────────────────
class TrustScoreCard extends StatelessWidget {
  final double trustScore;
  const TrustScoreCard({super.key, required this.trustScore});

  @override
  Widget build(BuildContext context) {
    final score = trustScore.clamp(0.0, 5.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.trust.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MnColors.trust.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.shield, color: MnColors.trust),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trust-Score',
                  style: MnTypography.label(color: MnColors.mute),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      score.toStringAsFixed(1),
                      style: MnTypography.mono(
                        size: 24,
                        color: MnColors.trust,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ 5.0',
                      style: MnTypography.mono(color: MnColors.mute, size: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  11. CommunityPulse — Aktivitaet der Community
//      1:1 zu /src/app/dashboard/components/CommunityPulse
// ─────────────────────────────────────────────────────────────────────
class CommunityPulseWidget extends StatelessWidget {
  final int activeNeighbors;
  final int totalNeighbors;
  const CommunityPulseWidget({
    super.key,
    required this.activeNeighbors,
    required this.totalNeighbors,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalNeighbors == 0 ? 0.0 : activeNeighbors / totalNeighbors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: MnColors.leben,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Community-Puls',
                style: MnTypography.label(color: MnColors.mute),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$activeNeighbors',
            style: MnTypography.mono(
              size: 28,
              color: MnColors.leben,
              weight: FontWeight.w700,
            ),
          ),
          Text(
            'aktive Nachbarn (24h)',
            style: MnTypography.body(color: MnColors.inkSoft, size: 12),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: MnColors.surface,
              valueColor: const AlwaysStoppedAnimation(MnColors.leben),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
//  12. ActivityFeed — chronologische Aktivitaeten
//      1:1 zu /src/app/dashboard/components/ActivityFeed
// ─────────────────────────────────────────────────────────────────────
class ActivityFeedWidget extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  const ActivityFeedWidget({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Aktivitaet in der Community',
            style: MnTypography.display(size: 18),
          ),
        ),
        if (activities.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MnColors.surface,
              borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
              border: Border.all(color: MnColors.line),
            ),
            child: Center(
              child: Text(
                'Noch keine Aktivitaet.',
                style: MnTypography.body(color: MnColors.mute),
              ),
            ),
          )
        else
          ...activities.take(8).map(
            (a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MnColors.elevated,
                borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                border: Border.all(color: MnColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: MnColors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.activity,
                      size: 16,
                      color: MnColors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (a['type'] as String?) ?? 'Interaktion',
                      style: MnTypography.body(
                        color: MnColors.inkSoft,
                        size: 13,
                      ),
                    ),
                  ),
                  Text(
                    _short((a['created_at'] as String?) ?? ''),
                    style: MnTypography.mono(size: 11, color: MnColors.mute),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _short(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ─────────────────────────────────────────────────────────────────────
//  13. ThanksReceived
//      1:1 zu /src/app/dashboard/components/ThanksReceived
// ─────────────────────────────────────────────────────────────────────
class ThanksReceivedWidget extends ConsumerWidget {
  final String userId;
  const ThanksReceivedWidget({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thanks = ref.watch(_thanksProvider(userId));
    return thanks.maybeWhen(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MnColors.elevated,
            borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
            border: Border.all(
              color: MnColors.herzrotWarm.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.heart, color: MnColors.herzrotWarm),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count Danke erhalten',
                      style: MnTypography.body(
                        color: MnColors.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Du bist eine Bereicherung der Nachbarschaft.',
                      style: MnTypography.body(
                        color: MnColors.inkSoft,
                        size: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

final _thanksProvider = FutureProvider.family<int, String>((ref, userId) async {
  try {
    final res = await supabase.client
        .from('thanks')
        .select('id')
        .eq('to_user_id', userId);
    return (res as List).length;
  } catch (_) {
    return 0;
  }
});
