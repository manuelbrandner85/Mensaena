import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// /dashboard/community — Trending Community Posts + Stats.
class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _posts = const [];
  Map<String, int> _stats = const {};

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
          .select('id, title, description, type, category, created_at, '
              'profiles:user_id(name, avatar_url)')
          .inFilter('type', ['community', 'rescue'])
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);
      final list = List<Map<String, dynamic>>.from(rows);

      // Lokale Stats berechnen
      final counts = <String, int>{
        'community': 0,
        'rescue': 0,
        'general': 0,
        'knowledge': 0,
      };
      for (final p in list) {
        final t = p['type'] as String?;
        final c = p['category'] as String?;
        if (t == 'community') counts['community'] = (counts['community'] ?? 0) + 1;
        if (t == 'rescue') counts['rescue'] = (counts['rescue'] ?? 0) + 1;
        if (c == 'general') counts['general'] = (counts['general'] ?? 0) + 1;
        if (c == 'knowledge') counts['knowledge'] = (counts['knowledge'] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _posts = list;
        _stats = counts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Beitrag erstellen',
            onPressed: () =>
                context.go(Routes.dashboardCommunityCreate),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _CommunityPulse(stats: _stats),
                  const SizedBox(height: 16),
                  const Text(
                    'Beliebt in der Community',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'Noch keine Community-Beiträge.',
                          style: TextStyle(color: AppColors.ink400),
                        ),
                      ),
                    )
                  else
                    ..._posts.map((p) => _PostTile(data: p)),
                ],
              ),
      ),
    );
  }
}

class _CommunityPulse extends StatelessWidget {
  const _CommunityPulse({required this.stats});
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('💬', 'Diskussionen', stats['community'] ?? 0),
      ('🆘', 'Fragen', stats['rescue'] ?? 0),
      ('📚', 'Wissen', stats['knowledge'] ?? 0),
      ('🎯', 'Allgemein', stats['general'] ?? 0),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary500, AppColors.primary700],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🌍 Community-Puls',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.9,
            children: tiles
                .map(
                  (t) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.$1, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(
                          '${t.$3}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          t.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final desc = data['description'] as String? ?? '';
    final type = data['type'] as String? ?? '';
    final created = data['created_at'] as String?;
    final time = created != null
        ? DateFormat('d. MMM', 'de').format(DateTime.parse(created))
        : '';
    final profile = data['profiles'] as Map<String, dynamic>?;
    final author = profile?['name'] as String? ?? 'Anonym';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('${Routes.dashboardPosts}/${data['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: type == 'rescue'
                            ? const Color(0xFFFEF3C7)
                            : AppColors.primary500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type == 'rescue' ? '🆘 Frage' : '💬 Idee',
                        style: TextStyle(
                          color: type == 'rescue'
                              ? const Color(0xFFD97706)
                              : AppColors.primary500,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.ink400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink700,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'von $author',
                  style: const TextStyle(
                    color: AppColors.ink400,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
