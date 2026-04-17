import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/knowledge_service.dart';
import 'package:mensaena/models/knowledge_article.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/editorial_header.dart';

final _knowledgeServiceProvider = Provider<KnowledgeService>((ref) => KnowledgeService(ref.watch(supabaseProvider)));

class WikiScreen extends ConsumerStatefulWidget {
  const WikiScreen({super.key});
  @override
  ConsumerState<WikiScreen> createState() => _WikiScreenState();
}

class _WikiScreenState extends ConsumerState<WikiScreen> {
  List<KnowledgeArticle> _articles = [];
  bool _loading = true;
  String _search = '';
  String? _selectedCategory;

  static const _categories = [
    (value: null, label: 'Alle', emoji: '📋'),
    (value: 'everyday', label: 'Alltag', emoji: '📖'),
    (value: 'skills', label: 'Handwerk', emoji: '🔧'),
    (value: 'food', label: 'Ernährung', emoji: '🥗'),
    (value: 'knowledge', label: 'Wissen', emoji: '📚'),
    (value: 'general', label: 'Sonstiges', emoji: '🌿'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final articles = await ref.read(_knowledgeServiceProvider).getArticles(
        category: _selectedCategory,
        search: _search.isNotEmpty ? _search : null,
      );
      if (mounted) setState(() => _articles = articles);
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wiki')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: EditorialHeader(
              section: 'WIKI',
              number: '29',
              title: 'Wiki',
              subtitle: 'Nachbarschafts-Wissen',
              icon: Icons.auto_stories_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Artikel suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true, fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (v) { _search = v; _load(); },
            ),
          ),
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
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary500,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _articles.isEmpty
                      ? const EmptyState(icon: Icons.menu_book_outlined, title: 'Keine Artikel', message: 'Schreibe den ersten Wiki-Artikel!')
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _articles.length,
                          itemBuilder: (_, i) => _ArticleCard(article: _articles[i]),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final KnowledgeArticle article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              if (article.summary != null) ...[
                const SizedBox(height: 4),
                Text(article.summary!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  if (article.category != null) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(6)),
                    child: Text(article.category!, style: const TextStyle(fontSize: 10, color: AppColors.primary700)),
                  ),
                  const Spacer(),
                  const Icon(Icons.visibility_outlined, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text('${article.views}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(width: 10),
                  Text(timeago.format(article.createdAt, locale: 'de'), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              if (article.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 4, runSpacing: 2, children: article.tags.take(4).map((t) => Text('#$t', style: const TextStyle(fontSize: 10, color: AppColors.primary500))).toList()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
