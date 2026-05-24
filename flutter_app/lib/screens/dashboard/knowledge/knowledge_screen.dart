import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/knowledge_article.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// Wissen / Wiki — knowledge_articles tabelle.
/// 1:1 zu Web src/app/dashboard/wiki/page.tsx — Suche, Kategorie-Filter,
/// Chips, Detail-Sheet mit Inhalt.
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

// 1:1 zu Web `WIKI_CATEGORIES`
const _wikiCategories = <_WikiCategory>[
  _WikiCategory('everyday', '📖', 'Alltag & Ratgeber'),
  _WikiCategory('skills', '🔧', 'Handwerk & Anleitung'),
  _WikiCategory('knowledge', '🧠', 'Wissen & Bildung'),
  _WikiCategory('housing', '⚖️', 'Wohnen & Recht'),
  _WikiCategory('mental', '💚', 'Gesundheit & Wohlbefinden'),
  _WikiCategory('emergency', '🚨', 'Notfall-Tipps'),
  _WikiCategory('sharing', '🌱', 'Nachhaltigkeit & Teilen'),
  _WikiCategory('food', '🍽️', 'Ernährung & Kochen'),
  _WikiCategory('mobility', '🚲', 'Mobilität & Unterwegs'),
  _WikiCategory('animals', '🐾', 'Tiere & Natur'),
  _WikiCategory('moving', '📦', 'Umzug & Neuanfang'),
  _WikiCategory('general', '💻', 'Digital & Sonstiges'),
];

class _WikiCategory {
  const _WikiCategory(this.value, this.emoji, this.label);
  final String value;
  final String emoji;
  final String label;
}

class _KnowledgeScreenState extends ConsumerState<KnowledgeScreen> {
  Future<List<KnowledgeArticle>>? _future;
  String _search = '';
  String _filterCat = 'all';

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
          .limit(200);
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

  bool _matches(KnowledgeArticle a) {
    if (_filterCat != 'all' && a.category != _filterCat) return false;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      final t = a.title.toLowerCase();
      final c = a.content.toLowerCase();
      final summ = (a.summary ?? '').toLowerCase();
      final tagsMatch = a.tags.any((t) => t.toLowerCase().contains(q));
      if (!t.contains(q) && !c.contains(q) && !summ.contains(q) && !tagsMatch) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: widget.title,
      currentRoute: widget.routePath,
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.bronze,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('${widget.routePath}/create'),
        icon: const Icon(LucideIcons.plus),
        label: Text('knowledge.article'.tr()),
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
              final all = snap.data ?? const <KnowledgeArticle>[];
              final filtered = all.where(_matches).toList();

              // Kategorie-Counts
              final catCounts = <String, int>{};
              for (final a in all) {
                final c = a.category;
                if (c == null) continue;
                catCounts[c] = (catCounts[c] ?? 0) + 1;
              }

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  // Header-Editorial: Wissensbasis
                  _EditorialHeader(
                    total: all.length,
                    categories: catCounts.length,
                  ),
                  const SizedBox(height: 14),

                  // Suche + Kategorie-Dropdown
                  _SearchBar(
                    value: _search,
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 10),

                  // Kategorie-Chips
                  if (catCounts.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _CategoryChip(
                          label: 'Alle',
                          emoji: '🗂️',
                          count: all.length,
                          active: _filterCat == 'all',
                          onTap: () => setState(() => _filterCat = 'all'),
                        ),
                        for (final c in _wikiCategories.where(
                            (c) => (catCounts[c.value] ?? 0) > 0))
                          _CategoryChip(
                            label: c.label,
                            emoji: c.emoji,
                            count: catCounts[c.value]!,
                            active: _filterCat == c.value,
                            onTap: () => setState(() => _filterCat =
                                _filterCat == c.value ? 'all' : c.value),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Liste
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(LucideIcons.bookOpen,
                                size: 36, color: AppColors.mute),
                            const SizedBox(height: 10),
                            Text(
                              all.isEmpty
                                  ? 'Noch keine Artikel.'
                                  : 'Keine Artikel gefunden.',
                              style: AppTypography.body(
                                size: 14,
                                color: AppColors.ink,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Teile dein Wissen mit der Gemeinschaft.',
                              style: AppTypography.body(
                                  size: 12, color: AppColors.mute),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () => context
                                  .go('${widget.routePath}/create'),
                              icon: const Icon(LucideIcons.plus, size: 14),
                              label: Text('knowledge.writeArticle'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.bronze,
                                foregroundColor: AppColors.voidColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final a in filtered)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ArticleTile(article: a),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Editorial Header ─────────────────────────────────────────────
class _EditorialHeader extends StatelessWidget {
  const _EditorialHeader({required this.total, required this.categories});
  final int total;
  final int categories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('§ 13 / Wissen',
            style: AppTypography.label(size: 9, color: AppColors.mute)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.bookOpen,
                  color: AppColors.bronze, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wissensbasis',
                    style: AppTypography.display(
                        size: 22, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ratgeber, Anleitungen und Wissen für die Gemeinschaft.',
                    style: AppTypography.body(
                        size: 12, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _StatBadge(label: 'Artikel', value: '$total'),
            _StatBadge(label: 'Kategorien', value: '$categories'),
          ],
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: AppTypography.mono(size: 11, color: AppColors.ink)),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.label(size: 9, color: AppColors.mute)),
        ],
      ),
    );
  }
}

// ── Search Bar ───────────────────────────────────────────────────
class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: AppTypography.body(size: 14, color: AppColors.ink),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.elevated,
        prefixIcon: const Icon(LucideIcons.search,
            size: 16, color: AppColors.mute),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(LucideIcons.x,
                    size: 14, color: AppColors.mute),
                onPressed: () {
                  _ctrl.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              )
            : null,
        hintText: 'Artikel suchen…',
        hintStyle: AppTypography.body(size: 13, color: AppColors.mute),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      ),
    );
  }
}

// ── Category Chip ────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.bronze.withValues(alpha: 0.22)
              : AppColors.elevated,
          border: Border.all(
            color: active ? AppColors.bronze : AppColors.line,
            width: active ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.body(
                    size: 11,
                    color: active ? AppColors.bronze : AppColors.inkSoft,
                    weight: FontWeight.w600)),
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.voidColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count',
                  style: AppTypography.mono(
                      size: 9,
                      color: active ? AppColors.bronze : AppColors.mute)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Article Tile ─────────────────────────────────────────────────
class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article});
  final KnowledgeArticle article;

  String _categoryEmoji(String? cat) {
    if (cat == null) return '📋';
    for (final c in _wikiCategories) {
      if (c.value == cat) return c.emoji;
    }
    return '📋';
  }

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
                color: AppColors.bronze.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_categoryEmoji(article.category),
                  style: const TextStyle(fontSize: 18)),
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
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      article.content.length > 120
                          ? '${article.content.substring(0, 120)}…'
                          : article.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (article.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.elevated,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(article.category!,
                              style: AppTypography.label(
                                  size: 8, color: AppColors.bronzeSoft)),
                        ),
                      const Spacer(),
                      const Icon(LucideIcons.clock,
                          size: 10, color: AppColors.mute),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('dd.MM.yyyy').format(article.createdAt),
                        style: AppTypography.caption(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(LucideIcons.chevronRight,
                size: 14, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}

// ── Article Detail Sheet ─────────────────────────────────────────
class _ArticleSheet extends StatelessWidget {
  const _ArticleSheet({required this.article});
  final KnowledgeArticle article;

  String _categoryLabel(String? cat) {
    if (cat == null) return '';
    for (final c in _wikiCategories) {
      if (c.value == cat) return '${c.emoji} ${c.label}';
    }
    return cat;
  }

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
          if (article.category != null)
            Text(_categoryLabel(article.category),
                style: AppTypography.label(
                    size: 10, color: AppColors.bronzeSoft)),
          const SizedBox(height: 6),
          Text(
            article.title,
            style: AppTypography.display(
              size: 24,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 11, color: AppColors.mute),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd. MMMM yyyy', 'de_DE').format(article.createdAt),
                style: AppTypography.caption(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (article.summary != null && article.summary!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.08),
                border:
                    Border.all(color: AppColors.bronze.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                article.summary!,
                style: AppTypography.body(
                    size: 13, color: AppColors.ink, height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            article.content,
            style: AppTypography.body(
              size: 14,
              color: AppColors.inkSoft,
              height: 1.7,
            ),
          ),
          if (article.tags.isNotEmpty) ...[
            const SizedBox(height: 18),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
