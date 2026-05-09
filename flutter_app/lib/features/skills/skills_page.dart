import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/page_chrome.dart';

/// /dashboard/skills — Skills-Übersicht (Anbieter / Suchende / Mentoren)
/// Pendant zu src/app/dashboard/skills/page.tsx.
class SkillsPage extends ConsumerStatefulWidget {
  const SkillsPage({super.key});

  @override
  ConsumerState<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends ConsumerState<SkillsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _posts = const [];
  Map<String, int> _topSkills = const {};
  Map<String, int> _stats = const {};
  String _filter = 'all';

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
          .select('id, title, description, type, category, tags, created_at, '
              'profiles:user_id(name, avatar_url)')
          .or('category.eq.skills,type.eq.sharing')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(50);
      final list = List<Map<String, dynamic>>.from(rows);

      // Top skills aggregieren (aus tags)
      final tagCounts = <String, int>{};
      var offered = 0, sought = 0, mentors = 0;
      for (final p in list) {
        final tags = p['tags'];
        if (tags is List) {
          for (final t in tags) {
            if (t is String && t.isNotEmpty) {
              tagCounts[t] = (tagCounts[t] ?? 0) + 1;
            }
          }
        }
        final type = p['type'] as String?;
        if (type == 'sharing') offered++;
        if (type == 'rescue') sought++;
        // Mentor-Heuristik: tag enthält "mentor"
        if (tags is List &&
            tags.any((t) =>
                t is String && t.toLowerCase().contains('mentor'))) {
          mentors++;
        }
      }
      // Sortiere top skills (Top 10)
      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = <String, int>{};
      for (final e in sortedTags.take(10)) {
        top[e.key] = e.value;
      }

      if (!mounted) return;
      setState(() {
        _posts = list;
        _topSkills = top;
        _stats = {
          'offered': offered,
          'sought': sought,
          'mentors': mentors,
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _posts;
    if (_filter == 'offered') {
      return _posts.where((p) => p['type'] == 'sharing').toList();
    }
    if (_filter == 'sought') {
      return _posts.where((p) => p['type'] == 'rescue').toList();
    }
    return _posts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Skills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Skill teilen',
            onPressed: () =>
                context.go(Routes.dashboardSkillsCreate),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const SkeletonList(count: 5)
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  const HeroHeader(
                    metaLabel: 'Skills',
                    title: 'Wissen, das verbindet',
                    subtitle:
                        'Biete deine Talente an, suche Hilfe oder finde Mentoren — '
                        'Nachbarschaftshilfe auf Augenhöhe.',
                    icon: Icons.auto_awesome_outlined,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            emoji: '🎁',
                            count: '${_stats['offered'] ?? 0}',
                            label: 'Angeboten',
                            accent: AppColors.primary500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            emoji: '🔍',
                            count: '${_stats['sought'] ?? 0}',
                            label: 'Gesucht',
                            accent: const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatTile(
                            emoji: '🎓',
                            count: '${_stats['mentors'] ?? 0}',
                            label: 'Mentoren',
                            accent: const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_topSkills.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🏆 Top Skills',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _topSkills.entries
                                .map(
                                  (e) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary500
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '#${e.key} · ${e.value}',
                                      style: const TextStyle(
                                        color: AppColors.primary500,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Alle',
                          selected: _filter == 'all',
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '🎁 Angeboten',
                          selected: _filter == 'offered',
                          onTap: () => setState(() => _filter = 'offered'),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '🔍 Gesucht',
                          selected: _filter == 'sought',
                          onTap: () => setState(() => _filter = 'sought'),
                        ),
                      ],
                    ),
                  ),
                  if (_filtered.isEmpty)
                    const EmptyState(
                      emoji: '🎯',
                      title: 'Noch keine Skills',
                      subtitle:
                          'Probier einen anderen Filter oder teile selbst dein '
                          'Wissen — der erste Eintrag inspiriert die Community.',
                      padding: EdgeInsets.symmetric(vertical: 32),
                    )
                  else
                    ..._filtered.map(
                      (p) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _PostTile(data: p),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.count,
    required this.label,
    required this.accent,
  });
  final String emoji, count, label;
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
          Text(emoji, style: const TextStyle(fontSize: 22)),
          Text(
            count,
            style: TextStyle(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary500.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary500 : AppColors.ink700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12,
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
          onTap: () =>
              context.go('${Routes.dashboardPosts}/${data['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: type == 'sharing'
                            ? AppColors.primary500.withValues(alpha: 0.12)
                            : const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        type == 'sharing' ? '🎁 Angeboten' : '🔍 Gesucht',
                        style: TextStyle(
                          color: type == 'sharing'
                              ? AppColors.primary500
                              : const Color(0xFF1E40AF),
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
