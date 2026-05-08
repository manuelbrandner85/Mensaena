import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../posts/models.dart';
import '../posts/posts_page.dart' show PostListTile;
import '../posts/posts_repository.dart';

/// Pendant zu /dashboard/animals. Tier-spezifischer View, der gefilterte
/// Posts zeigt (type='animal' oder rescue/crisis mit category='animals').
class AnimalsPage extends ConsumerStatefulWidget {
  const AnimalsPage({super.key});

  @override
  ConsumerState<AnimalsPage> createState() => _AnimalsPageState();
}

class _AnimalsPageState extends ConsumerState<AnimalsPage> {
  List<Post> _posts = [];
  _AnimalStats _stats = const _AnimalStats();
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
      final rows = await db
          .from('posts')
          .select(
            '*, profiles(name, avatar_url, trust_score, trust_score_count)',
          )
          .eq('status', 'active')
          .or(
            'type.eq.animal,and(type.in.(rescue,crisis),category.eq.animals)',
          )
          .order('urgency', ascending: false)
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      final posts = rows.map(Post.fromJson).toList();
      setState(() {
        _posts = posts;
        _stats = _AnimalStats(
          lost: posts.where((p) => p.type == 'crisis').length,
          found: posts.where((p) => p.type == 'animal').length,
          shelter: posts.where((p) => p.type == 'rescue').length,
          emergency: posts.where((p) => (p.urgency ?? 0) >= 3).length,
        );
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
      appBar: AppBar(
        title: const Text('Tiere'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tier melden',
            onPressed: () => context.go(Routes.dashboardAnimalsCreate),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatsRow(stats: _stats),
                  const SizedBox(height: 16),
                  if (_posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🐾', style: TextStyle(fontSize: 48)),
                            SizedBox(height: 12),
                            Text(
                              'Keine Tier-Posts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Melde ein vermisstes Tier oder ein Fundtier.',
                              style: TextStyle(
                                color: AppColors.ink400,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._posts.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PostListTile(post: p),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _AnimalStats {
  const _AnimalStats({
    this.lost = 0,
    this.found = 0,
    this.shelter = 0,
    this.emergency = 0,
  });
  final int lost;
  final int found;
  final int shelter;
  final int emergency;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final _AnimalStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = <_StatCardData>[
      _StatCardData(
        label: 'Vermisst',
        value: stats.lost,
        emoji: '⚠️',
        color: const Color(0xFFC62828),
      ),
      _StatCardData(
        label: 'Gefunden',
        value: stats.found,
        emoji: '🐾',
        color: AppColors.primary500,
      ),
      _StatCardData(
        label: 'Pflege',
        value: stats.shelter,
        emoji: '❤️',
        color: const Color(0xFFEC4899),
      ),
      _StatCardData(
        label: 'Notfälle',
        value: stats.emergency,
        emoji: '🚨',
        color: const Color(0xFFF97316),
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: cards.map((c) => _StatCard(data: c)).toList(),
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });
  final String label;
  final int value;
  final String emoji;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: data.color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(data.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            '${data.value}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: data.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.ink400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
