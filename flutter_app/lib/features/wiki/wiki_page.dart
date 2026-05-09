import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// Pendant zu /dashboard/wiki. Liest aus `knowledge_articles`.
/// Markdown-Rendering via flutter_markdown.
class WikiPage extends ConsumerStatefulWidget {
  const WikiPage({super.key});

  @override
  ConsumerState<WikiPage> createState() => _WikiPageState();
}

class _WikiPageState extends ConsumerState<WikiPage> {
  List<Map<String, dynamic>> _articles = const [];
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
          .from('knowledge_articles')
          .select('*, profiles:author_id(name, avatar_url)')
          .eq('status', 'published')
          .order('updated_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _articles = List<Map<String, dynamic>>.from(rows);
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

  void _open(Map<String, dynamic> a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.96,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => _ArticleView(article: a, scrollController: ctrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Wiki')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Noch keine Artikel',
                      style: TextStyle(color: AppColors.ink400),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ArticleTile(
                      article: _articles[i],
                      onTap: () => _open(_articles[i]),
                    ),
                  ),
                ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article, required this.onTap});
  final Map<String, dynamic> article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final updated = article['updated_at'] as String?;
    final time = updated != null
        ? DateFormat('d. MMM yyyy', 'de').format(DateTime.parse(updated))
        : '';
    final profile = article['profiles'] as Map<String, dynamic>?;
    final authorName = profile?['name'] as String? ?? 'Unbekannt';
    final excerpt = (article['summary'] ?? article['excerpt'] ?? '').toString();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (article['category'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        article['category'] as String,
                        style: const TextStyle(
                          color: AppColors.primary500,
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
                article['title'] as String? ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (excerpt.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink700,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 12, color: AppColors.ink400),
                  const SizedBox(width: 2),
                  Text(
                    authorName,
                    style: const TextStyle(
                      color: AppColors.ink400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleView extends StatelessWidget {
  const _ArticleView({required this.article, required this.scrollController});
  final Map<String, dynamic> article;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final content = article['content'] as String? ?? '';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  article['title'] as String? ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: Markdown(
            controller: scrollController,
            data: content,
            padding: const EdgeInsets.all(16),
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: const TextStyle(fontSize: 15, height: 1.6),
              h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              h3: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              blockquote: const TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.ink400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
