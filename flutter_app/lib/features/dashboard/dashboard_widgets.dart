import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// 4er-Reihe mit Profil-Stats: Trust / Posts / Helfer / Bewertungen.
/// Pendant zu StatsCards.tsx im Web-Dashboard.
class DashboardStatsRow extends ConsumerStatefulWidget {
  const DashboardStatsRow({super.key});

  @override
  ConsumerState<DashboardStatsRow> createState() => _DashboardStatsRowState();
}

class _DashboardStatsRowState extends ConsumerState<DashboardStatsRow> {
  bool _loading = true;
  double _trust = 0;
  int _trustCount = 0;
  int _posts = 0;
  int _helped = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(supabaseProvider);
    final user = db.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final p = await db
          .from('profiles')
          .select('trust_score, trust_score_count')
          .eq('id', user.id)
          .maybeSingle();
      Future<int> safeCount(String table, String filter) async {
        try {
          final rows = await db.from(table).select('id').eq(filter, user.id);
          return rows.length;
        } catch (_) {
          return 0;
        }
      }

      final results = await Future.wait<int>([
        safeCount('posts', 'user_id'),
        safeCount('interactions', 'helper_id'),
      ]);
      if (!mounted) return;
      setState(() {
        _trust = (p?['trust_score'] as num?)?.toDouble() ?? 0;
        _trustCount = (p?['trust_score_count'] as num?)?.toInt() ?? 0;
        _posts = results[0];
        _helped = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            emoji: '⭐',
            value: _trust > 0 ? _trust.toStringAsFixed(1) : '—',
            label: 'Trust',
            sub: '$_trustCount Bew.',
            accent: const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            emoji: '📝',
            value: '$_posts',
            label: 'Posts',
            sub: 'erstellt',
            accent: AppColors.primary500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            emoji: '🤝',
            value: '$_helped',
            label: 'Geholfen',
            sub: 'Personen',
            accent: const Color(0xFF3B82F6),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.sub,
    required this.accent,
  });
  final String emoji, value, label, sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink800,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            sub,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink400,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent-Activity-Feed: zeigt letzte 5 Posts der Community + die letzten 3
/// eigenen Interaktionen (chronologisch).
/// Pendant zu ActivityFeed.tsx (vereinfacht).
class DashboardActivityFeed extends ConsumerStatefulWidget {
  const DashboardActivityFeed({super.key});

  @override
  ConsumerState<DashboardActivityFeed> createState() =>
      _DashboardActivityFeedState();
}

class _DashboardActivityFeedState
    extends ConsumerState<DashboardActivityFeed> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ref
          .read(supabaseProvider)
          .from('posts')
          .select('id, title, type, created_at, profiles:user_id(name)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(5);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Row(
            children: [
              const Text(
                '✨ Neu in der Community',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.ink800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go(Routes.dashboardPosts),
                child: const Text('Alle'),
              ),
            ],
          ),
        ),
        ..._items.map((row) => _FeedRow(data: row)),
      ],
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.data});
  final Map<String, dynamic> data;

  String get _typeEmoji {
    switch (data['type']) {
      case 'rescue':
        return '🆘';
      case 'animal':
        return '🐾';
      case 'housing':
        return '🏡';
      case 'supply':
        return '🌾';
      case 'mobility':
        return '🚗';
      case 'sharing':
        return '🔄';
      case 'community':
        return '💬';
      case 'crisis':
        return '🚨';
      default:
        return '📝';
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String;
    final title = data['title'] as String? ?? '—';
    final created = data['created_at'] as String?;
    final time = created != null
        ? DateFormat('HH:mm', 'de').format(DateTime.parse(created))
        : '';
    final profile = data['profiles'] as Map<String, dynamic>?;
    final author = profile?['name'] as String? ?? 'Anonym';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go('${Routes.dashboardPosts}/$id'),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              children: [
                Text(_typeEmoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '$author · $time',
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.ink400,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
