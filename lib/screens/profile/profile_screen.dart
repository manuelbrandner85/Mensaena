import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/trust_score_badge.dart';
import 'package:mensaena/models/user_profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final userId = ref.watch(currentUserIdProvider);
    final stats =
        userId != null ? ref.watch(profileStatsProvider(userId)) : null;
    final activity =
        userId != null ? ref.watch(recentActivityProvider(userId)) : null;

    return Scaffold(
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (p) {
          if (p == null) {
            return const Center(child: Text('Profil nicht gefunden'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentProfileProvider);
              if (userId != null) {
                ref.invalidate(profileStatsProvider(userId));
                ref.invalidate(recentActivityProvider(userId));
              }
            },
            child: CustomScrollView(
              slivers: [
                // Hero banner + avatar + name overlay
                SliverToBoxAdapter(
                  child: _ProfileHero(profile: p, onEdit: () => context.push('/dashboard/profile/edit')),
                ),
                // Stats grid
                if (stats != null)
                  SliverToBoxAdapter(
                    child: stats.when(
                      data: (s) => _StatsGrid(stats: s),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                // Activity feed header
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Text(
                      'Aktivitaeten',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                // Activity feed list
                if (activity != null)
                  activity.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Text(
                              'Noch keine Aktivitaeten vorhanden.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        );
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _ActivityItem(
                              item: items[index],
                              isLast: index == items.length - 1,
                            ),
                            childCount: items.length,
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (_, __) => const SliverToBoxAdapter(
                      child: SizedBox.shrink(),
                    ),
                  ),
                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero banner with gradient, decorative elements, avatar, name, meta
// ---------------------------------------------------------------------------
class _ProfileHero extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onEdit;

  const _ProfileHero({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final memberSince = DateFormat('MMMM yyyy', 'de_DE').format(profile.createdAt);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient banner
        Container(
          height: 180,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary500,
                AppColors.primary700,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                top: 20,
                left: 40,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Edit button
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    }
                  },
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 8,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onEdit,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Bearbeiten',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Content below the banner
        Padding(
          padding: const EdgeInsets.only(top: 116),
          child: Column(
            children: [
              // Avatar with white ring and glow
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary500.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AvatarWidget(
                    imageUrl: profile.avatarUrl,
                    name: profile.displayName,
                    size: 128,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Name
              Text(
                profile.displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              // Nickname
              if (profile.nickname != null && profile.nickname!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '@${profile.nickname}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Trust score badge
              Center(
                child: TrustScoreBadge(
                  score: profile.trustScore,
                  size: TrustBadgeSize.large,
                ),
              ),
              const SizedBox(height: 12),
              // Meta row: location + member since
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (profile.location != null && profile.location!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            profile.location!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Mitglied seit $memberSince',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Bio
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    profile.bio!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              // Offer / seek tags
              if (profile.offerTags.isNotEmpty || profile.seekTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _OfferSeekTags(offer: profile.offerTags, seek: profile.seekTags),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stats grid: 2x2 cards
// ---------------------------------------------------------------------------
class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final hoursGiven = (stats['hours_given'] as num?)?.toDouble() ?? 0;
    final hoursReceived = (stats['hours_received'] as num?)?.toDouble() ?? 0;
    final postsCount = (stats['posts_count'] as num?)?.toInt() ?? 0;
    final groupsCount = (stats['groups_count'] as num?)?.toInt() ?? 0;
    final challengesCount = (stats['challenges_count'] as num?)?.toInt() ?? 0;

    String fmt(double h) => h % 1 == 0 ? h.toInt().toString() : h.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.favorite_outline,
                  iconColor: AppColors.primary500,
                  iconBg: AppColors.primary50,
                  value: fmt(hoursGiven),
                  label: 'Stunden gegeben',
                  subtitle: 'Zeitbank',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.volunteer_activism_outlined,
                  iconColor: AppColors.trust,
                  iconBg: const Color(0xFFE0E7FF),
                  value: fmt(hoursReceived),
                  label: 'Stunden erhalten',
                  subtitle: 'Zeitbank',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.description_outlined,
                  iconColor: AppColors.info,
                  iconBg: const Color(0xFFDBEAFE),
                  value: '$postsCount',
                  label: 'Beiträge',
                  subtitle: 'Erstellt',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.people_outline,
                  iconColor: AppColors.categoryAnimal,
                  iconBg: const Color(0xFFEDE9FE),
                  value: '$groupsCount',
                  label: 'Gruppen',
                  subtitle: 'Mitglied',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events_outlined,
                  iconColor: AppColors.warning,
                  iconBg: const Color(0xFFFEF3C7),
                  value: '$challengesCount',
                  label: 'Challenges',
                  subtitle: 'Teilgenommen',
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Offer / seek tags: grüne "Ich biete" Chips + blaue "Ich suche" Chips
// ---------------------------------------------------------------------------
class _OfferSeekTags extends StatelessWidget {
  final List<String> offer;
  final List<String> seek;

  const _OfferSeekTags({required this.offer, required this.seek});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (offer.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.favorite_outline, size: 16, color: Color(0xFF059669)),
              SizedBox(width: 6),
              Text(
                'Ich biete an',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: offer.map((t) => _Chip(label: t, fg: const Color(0xFF065F46), bg: const Color(0xFFD1FAE5))).toList(),
          ),
          if (seek.isNotEmpty) const SizedBox(height: 14),
        ],
        if (seek.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.search, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 6),
              Text(
                'Ich suche',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: seek.map((t) => _Chip(label: t, fg: const Color(0xFF1E3A8A), bg: const Color(0xFFDBEAFE))).toList(),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const _Chip({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final String subtitle;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          // Value
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          // Subtitle
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity feed item with timeline dot
// ---------------------------------------------------------------------------
class _ActivityItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLast;

  const _ActivityItem({required this.item, required this.isLast});

  IconData _getIcon() {
    switch (item['icon']) {
      case 'clock':
        return Icons.access_time;
      case 'users':
        return Icons.people_outline;
      case 'trophy':
        return Icons.emoji_events_outlined;
      case 'file_text':
        return Icons.description_outlined;
      default:
        return Icons.circle;
    }
  }

  Color _getColor() {
    switch (item['type']) {
      case 'timebank':
        return AppColors.primary500;
      case 'group':
        return AppColors.categoryAnimal;
      case 'challenge':
        return AppColors.warning;
      case 'post':
        return AppColors.info;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
    if (diff.inDays < 30) return 'vor ${(diff.inDays / 7).floor()} Wochen';
    if (diff.inDays < 365) return 'vor ${(diff.inDays / 30).floor()} Monaten';
    return 'vor ${(diff.inDays / 365).floor()} Jahren';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column: dot + line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 4),
                // Dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.2),
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getIcon(), color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['description'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimeAgo(item['created_at']),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
