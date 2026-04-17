import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/editorial_header.dart';

class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({super.key});
  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  List<Post> _posts = [];
  Map<String, int> _stats = {};
  bool _loading = true;
  String _search = '';
  String? _selectedCategory;

  static const _categories = [
    (value: null, label: 'Alle', emoji: '📋'),
    (value: 'knowledge', label: 'Guides', emoji: '📖'),
    (value: 'skills', label: 'Fähigkeiten', emoji: '🛠️'),
    (value: 'general', label: 'Naturwissen', emoji: '🌿'),
    (value: 'mental', label: 'Selbstversorgung', emoji: '🧠'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Knowledge module: community + sharing + rescue posts with knowledge category
      final service = ref.read(postServiceProvider);
      final results = await Future.wait([
        service.getPosts(type: 'community', category: _selectedCategory ?? 'knowledge', search: _search.isNotEmpty ? _search : null),
        service.getPosts(type: 'sharing', category: _selectedCategory ?? 'knowledge', search: _search.isNotEmpty ? _search : null),
        service.getPosts(type: 'rescue', category: _selectedCategory ?? 'knowledge', search: _search.isNotEmpty ? _search : null),
      ]);
      final allPosts = [...results[0], ...results[1], ...results[2]];
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Stats
      final stats = <String, int>{
        'guides': results[0].length,
        'skills': results[1].length,
        'teaching': results[2].length,
      };

      if (mounted) setState(() { _posts = allPosts; _stats = stats; });
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildung & Wissen')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: EditorialHeader(
              section: 'WISSEN',
              number: '15',
              title: 'Wissensbank',
              subtitle: 'Artikel und Anleitungen',
              icon: Icons.menu_book_outlined,
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Wissen suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true, fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (v) { _search = v; _load(); },
            ),
          ),

          // Category filter
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final sel = _selectedCategory == c.value;
                return FilterChip(
                  label: Text('${c.emoji} ${c.label}', style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppColors.textSecondary)),
                  selected: sel, selectedColor: AppColors.primary500,
                  onSelected: (_) { setState(() => _selectedCategory = c.value); _load(); },
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // Stats cards
          if (!_loading && _stats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _StatMini(icon: Icons.article_outlined, label: 'Guides', value: _stats['guides'] ?? 0, color: AppColors.primary500),
                  const SizedBox(width: 8),
                  _StatMini(icon: Icons.school_outlined, label: 'Skills', value: _stats['skills'] ?? 0, color: const Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  _StatMini(icon: Icons.lightbulb_outline, label: 'Unterricht', value: _stats['teaching'] ?? 0, color: AppColors.info),
                ],
              ),
            ),
          if (!_loading && _stats.isNotEmpty) const SizedBox(height: 8),

          // Tip card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary200),
              ),
              child: const Text.rich(
                TextSpan(children: [
                  TextSpan(text: '💡 ', style: TextStyle(fontSize: 14)),
                  TextSpan(text: 'Wissen teilen = Gemeinschaft stärken. ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  TextSpan(text: 'Teile Guides, How-Tos oder Naturwissen.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Post list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary500,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _posts.isEmpty
                      ? const EmptyState(icon: Icons.menu_book_outlined, title: 'Noch keine Wissens-Beiträge', message: 'Teile dein Wissen mit der Gemeinschaft!')
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _posts.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PostCard(post: _posts[i], onTap: () => context.push('/dashboard/posts/${_posts[i].id}')),
                          ),
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/create'),
        icon: const Icon(Icons.add),
        label: const Text('Wissen teilen'),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _StatMini({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
