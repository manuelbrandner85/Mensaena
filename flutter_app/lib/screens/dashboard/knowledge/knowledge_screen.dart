import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/knowledge_article.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// Wissen / Wiki — knowledge_articles tabelle.
class KnowledgeScreen extends ConsumerStatefulWidget {
  const KnowledgeScreen({
    required this.title,
    required this.routePath,
    super.key,
  });

  final String title;
  final String routePath;

  @override
  ConsumerState<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  Future<List<KnowledgeArticle>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<KnowledgeArticle>> _load() async {
    try {
      final rows = await sb
          .from('knowledge_articles')
          .select()
          .eq('is_public', true)
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(KnowledgeArticle.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: widget.title,
      currentRoute: widget.routePath,
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.bronze,
        foregroundColor: AppColors.voidColor,
        onPressed: () =>
            context.go('${widget.routePath}/create'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Artikel'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<KnowledgeArticle>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                );
              }
              final list = snap.data ?? const <KnowledgeArticle>[];
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(LucideIcons.bookOpen,
                              size: 32, color: AppColors.mute),
                          const SizedBox(height: 10),
                          Text(
                            'Noch keine Artikel.',
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) =>
                    _ArticleTile(article: list[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article});
  final KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _ArticleSheet(article: article),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(LucideIcons.bookOpen,
                  color: AppColors.amber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (article.summary != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      article.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (article.category != null)
                        Text(article.category!,
                            style: AppTypography.label(size: 9)),
                      const Spacer(),
                      Text(
                        DateFormat('dd.MM.yyyy').format(article.createdAt),
                        style: AppTypography.caption(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleSheet extends StatelessWidget {
  const _ArticleSheet({required this.article});
  final KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            article.title,
            style: AppTypography.display(
              size: 24,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          if (article.category != null) ...[
            const SizedBox(height: 6),
            Text(article.category!, style: AppTypography.label(size: 10)),
          ],
          const SizedBox(height: 14),
          Text(
            article.content,
            style: AppTypography.body(
              size: 14,
              color: AppColors.inkSoft,
              height: 1.6,
            ),
          ),
          if (article.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: article.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '#$t',
                          style: AppTypography.body(
                            size: 11,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
