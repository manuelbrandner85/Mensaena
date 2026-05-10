import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// /dashboard/badges – zeigt alle Badges des Users.
class BadgesPage extends ConsumerStatefulWidget {
  const BadgesPage({super.key});

  @override
  ConsumerState<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends ConsumerState<BadgesPage> {
  List<Map<String, dynamic>> _badges = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final rows = await db
          .from('user_badges')
          .select('badge_id, earned_at, badges(name, description, emoji, points)')
          .eq('user_id', user.id)
          .order('earned_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _badges = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Badges')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _badges.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🏆', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text(
                          'Noch keine Badges',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Hilf in der Community, um Badges zu verdienen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.ink400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _LevelHeader(badges: _badges),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _BadgeCard(data: _badges[i]),
                            childCount: _badges.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// Berechnet Level aus Gesamt-Punktzahl. Klassische sqrt-Progression:
/// Level 1 ab 0 P, Level 2 ab 50, Level 3 ab 200, Level 4 ab 450, …
/// = `level = floor(sqrt(points / 50)) + 1`
int _levelFor(int points) => (sqrt(points / 50)).floor() + 1;

/// Schwelle (in Punkten) ab der `level` erreicht ist.
int _thresholdForLevel(int level) => 50 * (level - 1) * (level - 1);

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.badges});
  final List<Map<String, dynamic>> badges;

  @override
  Widget build(BuildContext context) {
    final total = badges.fold<int>(0, (sum, b) {
      final pts = ((b['badges'] as Map<String, dynamic>?)?['points'] as num?)
              ?.toInt() ??
          0;
      return sum + pts;
    });
    final level = _levelFor(total);
    final currentThreshold = _thresholdForLevel(level);
    final nextThreshold = _thresholdForLevel(level + 1);
    final progress = nextThreshold == currentThreshold
        ? 1.0
        : ((total - currentThreshold) /
                (nextThreshold - currentThreshold))
            .clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary500, AppColors.primary700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary500.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '$total Punkte · ${badges.length} Badges',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            level >= 50
                ? 'Maximal-Level erreicht!'
                : '${nextThreshold - total} Punkte bis Level ${level + 1}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final badge = data['badges'] as Map<String, dynamic>?;
    final earnedRaw = data['earned_at'] as String?;
    final earned = earnedRaw != null
        ? DateFormat('d. MMM yyyy', 'de').format(DateTime.parse(earnedRaw))
        : '';
    final emoji = badge?['emoji'] as String? ?? '🏅';
    final name = badge?['name'] as String? ?? 'Badge';
    final description = badge?['description'] as String? ?? '';
    final points = (badge?['points'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 38)),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink400,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
          const Spacer(),
          if (points > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary500.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$points P',
                style: const TextStyle(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            earned,
            style: const TextStyle(color: AppColors.ink400, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
