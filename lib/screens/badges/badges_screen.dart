import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/widgets/editorial_header.dart';
import 'package:mensaena/providers/auth_provider.dart';

// ---------- Inline providers for badges ----------

final _badgeServiceProvider = Provider<_BadgeService>((ref) {
  return _BadgeService(ref.watch(supabaseProvider));
});

final _allBadgesProvider = FutureProvider<List<_Badge>>((ref) async {
  return ref.read(_badgeServiceProvider).getAllBadges();
});

final _userBadgesProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  return ref.read(_badgeServiceProvider).getUserBadgeIds(userId);
});

final _userBadgeDetailsProvider =
    FutureProvider<Map<String, DateTime>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return {};
  return ref.read(_badgeServiceProvider).getUserBadgeEarnedDates(userId);
});

// ---------- Simple service ----------

class _BadgeService {
  final SupabaseClient _client;
  _BadgeService(this._client);

  Future<List<_Badge>> getAllBadges() async {
    final data =
        await _client.from('badges').select().order('points', ascending: true);
    return (data as List).map((e) => _Badge.fromJson(e)).toList();
  }

  Future<Set<String>> getUserBadgeIds(String userId) async {
    final data = await _client
        .from('user_badges')
        .select('badge_id')
        .eq('user_id', userId);
    return (data as List).map((e) => e['badge_id'] as String).toSet();
  }

  Future<Map<String, DateTime>> getUserBadgeEarnedDates(String userId) async {
    final data = await _client
        .from('user_badges')
        .select('badge_id, earned_at')
        .eq('user_id', userId);
    final map = <String, DateTime>{};
    for (final row in data as List) {
      map[row['badge_id'] as String] =
          DateTime.parse(row['earned_at'] as String);
    }
    return map;
  }
}

// ---------- Model ----------

class _Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final String requirementType;
  final int requirementValue;
  final int points;
  final String rarity;

  const _Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.requirementType,
    required this.requirementValue,
    required this.points,
    required this.rarity,
  });

  factory _Badge.fromJson(Map<String, dynamic> json) {
    return _Badge(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'award',
      category: json['category'] as String? ?? 'engagement',
      requirementType: json['requirement_type'] as String? ?? '',
      requirementValue: json['requirement_value'] as int? ?? 1,
      points: json['points'] as int? ?? 10,
      rarity: json['rarity'] as String? ?? 'common',
    );
  }
}

// ---------- Helper: icon from string ----------

IconData _iconFromString(String name) {
  const map = {
    'star': Icons.star,
    'zap': Icons.flash_on,
    'flame': Icons.local_fire_department,
    'book': Icons.menu_book,
    'heart': Icons.favorite,
    'shield': Icons.shield,
    'trophy': Icons.emoji_events,
    'users': Icons.people,
    'target': Icons.track_changes,
    'crown': Icons.workspace_premium,
    'calendar': Icons.calendar_month,
    'award': Icons.military_tech,
  };
  return map[name] ?? Icons.military_tech;
}

Color _rarityColor(String rarity) {
  switch (rarity) {
    case 'common':
      return AppColors.textMuted;
    case 'uncommon':
      return AppColors.success;
    case 'rare':
      return AppColors.info;
    case 'epic':
      return const Color(0xFF9333EA);
    case 'legendary':
      return const Color(0xFFFFD700);
    default:
      return AppColors.textMuted;
  }
}

String _rarityLabel(String rarity) {
  switch (rarity) {
    case 'common':
      return 'Gewoehnlich';
    case 'uncommon':
      return 'Ungewoehnlich';
    case 'rare':
      return 'Selten';
    case 'epic':
      return 'Episch';
    case 'legendary':
      return 'Legendaer';
    default:
      return rarity;
  }
}

String _categoryLabel(String category) {
  switch (category) {
    case 'engagement':
      return 'Engagement';
    case 'helper':
      return 'Helfer';
    case 'social':
      return 'Sozial';
    case 'knowledge':
      return 'Wissen';
    case 'special':
      return 'Spezial';
    default:
      return category;
  }
}

// ---------- Screen ----------

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(_allBadgesProvider);
    final earnedIdsAsync = ref.watch(_userBadgesProvider);
    final earnedDatesAsync = ref.watch(_userBadgeDetailsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: Column(children: [const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: EditorialHeader(
                section: 'BADGES',
                number: '25',
                title: 'Auszeichnungen',
                subtitle: 'Deine Erfolge und Abzeichen',
                icon: Icons.military_tech_outlined,
              ),
            ), Expanded(child: badgesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (badges) {
          final earnedIds = earnedIdsAsync.valueOrNull ?? {};
          final earnedDates = earnedDatesAsync.valueOrNull ?? {};

          if (badges.isEmpty) {
            return const Center(
              child: Text(
                'Noch keine Badges verfügbar.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          // Group by category
          final grouped = <String, List<_Badge>>{};
          for (final b in badges) {
            grouped.putIfAbsent(b.category, () => []).add(b);
          }

          // Sort categories in a fixed order
          const categoryOrder = [
            'engagement',
            'helper',
            'social',
            'knowledge',
            'special'
          ];
          final sortedCategories = grouped.keys.toList()
            ..sort((a, b) {
              final ia = categoryOrder.indexOf(a);
              final ib = categoryOrder.indexOf(b);
              return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
            });

          final earnedCount = badges.where((b) => earnedIds.contains(b.id)).length;
          final totalPoints = badges
              .where((b) => earnedIds.contains(b.id))
              .fold<int>(0, (sum, b) => sum + b.points);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_allBadgesProvider);
              ref.invalidate(_userBadgesProvider);
              ref.invalidate(_userBadgeDetailsProvider);
            },
            color: AppColors.primary500,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
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
                  child: Row(
                    children: [
                      const Icon(Icons.military_tech,
                          size: 48, color: Colors.white),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$earnedCount / ${badges.length} Badges',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$totalPoints Punkte gesammelt',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Categories
                ...sortedCategories.map((category) {
                  final categoryBadges = grouped[category]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _categoryLabel(category),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        itemCount: categoryBadges.length,
                        itemBuilder: (context, index) {
                          final badge = categoryBadges[index];
                          final earned = earnedIds.contains(badge.id);
                          final earnedAt = earnedDates[badge.id];
                          final rColor = _rarityColor(badge.rarity);

                          return GestureDetector(
                            onTap: () => _showBadgeDetail(
                                context, badge, earned, earnedAt),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: earned
                                    ? const Color(0xFFFFFBEB)
                                    : AppColors.borderLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: earned
                                      ? const Color(0xFFFFD700)
                                          .withValues(alpha: 0.5)
                                      : AppColors.border,
                                  width: earned ? 2 : 1,
                                ),
                                boxShadow: earned ? AppShadows.soft : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: earned
                                          ? const Color(0xFFFFD700)
                                              .withValues(alpha: 0.2)
                                          : AppColors.border,
                                      shape: BoxShape.circle,
                                      border: earned
                                          ? Border.all(
                                              color: const Color(0xFFFFD700)
                                                  .withValues(alpha: 0.4),
                                              width: 2)
                                          : null,
                                    ),
                                    child: Icon(
                                      _iconFromString(badge.icon),
                                      color: earned
                                          ? const Color(0xFFB8860B)
                                          : AppColors.textMuted,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    badge.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: earned
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: rColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${badge.points} P',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: earned
                                            ? rColor
                                            : AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  if (!earned)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(Icons.lock_outline,
                                          size: 12, color: AppColors.textMuted),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      )),
    ]),
    );
  }

  void _showBadgeDetail(
      BuildContext context, _Badge badge, bool earned, DateTime? earnedAt) {
    final rColor = _rarityColor(badge.rarity);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: earned
                    ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                    : AppColors.border,
                shape: BoxShape.circle,
                border: earned
                    ? Border.all(
                        color: const Color(0xFFFFD700), width: 3)
                    : null,
              ),
              child: Icon(
                _iconFromString(badge.icon),
                color: earned ? const Color(0xFFB8860B) : AppColors.textMuted,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.name,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: rColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _rarityLabel(badge.rarity),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: rColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${badge.points} Punkte',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary700,
                    ),
                  ),
                ),
              ],
            ),
            if (earned && earnedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Erhalten am ${DateFormat('dd.MM.yyyy', 'de').format(earnedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (!earned) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Noch nicht freigeschaltet',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schliessen'),
          ),
        ],
      ),
    );
  }
}
