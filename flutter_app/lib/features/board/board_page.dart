import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/realtime_feed.dart';
import 'board_repository.dart';
import 'models.dart';

class BoardPage extends ConsumerStatefulWidget {
  const BoardPage({super.key});

  @override
  ConsumerState<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends ConsumerState<BoardPage>
    with RealtimeFeedMixin {
  List<BoardPost> _allPosts = [];
  bool _loading = true;
  String _category = 'all';
  String _search = '';
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _sortBy = 'newest'; // newest | pinned

  @override
  String get realtimeChannelName => 'board-feed-realtime';

  @override
  List<FeedRealtimeRule> get realtimeRules => const [
        FeedRealtimeRule(
          event: PostgresChangeEvent.insert,
          table: 'board_posts',
          action: FeedRealtimeAction.bumpNewCount,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.update,
          table: 'board_posts',
          action: FeedRealtimeAction.reloadImmediately,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.delete,
          table: 'board_posts',
          action: FeedRealtimeAction.reloadImmediately,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.insert,
          table: 'board_post_comments',
          action: FeedRealtimeAction.reloadImmediately,
        ),
      ];

  @override
  Future<void> reloadFeed() => _load();

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _showNewItems() {
    resetNewItemCount();
    _load();
  }

  Future<void> _openDetail(BoardPost post) async {
    final didChange = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BoardDetailSheet(post: post),
    );
    if (didChange == true) {
      _load();
    }
  }

  /// Client-seitig gefilterte Liste basierend auf _search + _sortBy.
  /// Kategorie wird Server-seitig in `_load` gefiltert.
  List<BoardPost> get _posts {
    final query = _search.trim().toLowerCase();
    var filtered = _allPosts;
    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        final hayContent = p.content.toLowerCase();
        final hayCat = p.categoryConfig.label.toLowerCase();
        final hayContact = (p.contactInfo ?? '').toLowerCase();
        return hayContent.contains(query) ||
            hayCat.contains(query) ||
            hayContact.contains(query);
      }).toList();
    }
    // Sort
    filtered = [...filtered];
    if (_sortBy == 'pinned') {
      filtered.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    } else {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _load();
    subscribeRealtime();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(boardRepositoryProvider)
          .list(category: _category);
      if (!mounted) return;
      setState(() {
        _allPosts = list;
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

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _search = v);
    });
  }

  Future<void> _create() async {
    final result = await showModalBottomSheet<_NewPost>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => const _NewPostSheet(),
    );
    if (result == null) return;
    HapticFeedback.mediumImpact();
    try {
      await ref.read(boardRepositoryProvider).create(
            content: result.content,
            category: result.category,
            color: result.color,
            contactInfo: result.contact,
          );
      await _load();
    } catch (e) {
      if (!mounted) return;
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
        title: const Text('Pinnwand'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sortieren',
            initialValue: _sortBy,
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'newest', child: Text('Neueste zuerst')),
              PopupMenuItem(value: 'pinned', child: Text('Angepinnt zuerst')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Pin erstellen',
            onPressed: _create,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Pins durchsuchen…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Chip(
                  label: 'Alle',
                  selected: _category == 'all',
                  onTap: () {
                    setState(() => _category = 'all');
                    _load();
                  },
                ),
                ...BoardCategoryConfig.all.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _Chip(
                      label: '${c.emoji} ${c.label}',
                      selected: _category == c.value,
                      onTap: () {
                        setState(() => _category = c.value);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          NewItemsBanner(
            count: newItemCount,
            singularLabel: 'Aushang',
            pluralLabel: 'Aushänge',
            onTap: _showNewItems,
            icon: Icons.push_pin_outlined,
          ),
          Expanded(
            child: _loading
                ? const SkeletonList(count: 5)
                : _posts.isEmpty
                    ? EmptyState(
                        emoji: '📌',
                        title: _search.isNotEmpty
                            ? 'Nichts gefunden'
                            : 'Noch keine Pins',
                        subtitle: _search.isNotEmpty
                            ? 'Keine Pins zu „$_search" — probier einen anderen '
                                'Suchbegriff oder Filter.'
                            : 'Pinne den ersten Hinweis, Tipp oder die nächste '
                                'Idee an die Wand der Nachbarschaft.',
                        actionLabel:
                            _search.isEmpty ? 'Pin erstellen' : null,
                        onAction: _search.isEmpty ? _create : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: _posts.length,
                          itemBuilder: (_, i) => _PinCard(
                            post: _posts[i],
                            onTap: () => _openDetail(_posts[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
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
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({required this.post, required this.onTap});
  final BoardPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BoardColors.forName(post.color);
    final cat = post.categoryConfig;
    final time = DateFormat('d. MMM', 'de').format(post.createdAt);
    return Material(
      color: colors.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  cat.label,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (post.pinned) Icon(Icons.push_pin, size: 14, color: colors.text),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              post.content,
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          if (post.contactInfo != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.alternate_email, size: 12, color: colors.text),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    post.contactInfo!,
                    style: TextStyle(color: colors.text, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                post.authorName ?? 'Unbekannt',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                time,
                style: TextStyle(
                  color: colors.text.withValues(alpha: 0.7),
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

class _NewPost {
  const _NewPost({
    required this.content,
    required this.category,
    required this.color,
    this.contact,
  });
  final String content;
  final String category;
  final String color;
  final String? contact;
}

class _NewPostSheet extends StatefulWidget {
  const _NewPostSheet();

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final _content = TextEditingController();
  final _contact = TextEditingController();
  String _category = 'general';
  String _color = 'yellow';

  static const _colors = ['yellow', 'green', 'blue', 'pink', 'orange', 'purple'];

  @override
  void dispose() {
    _content.dispose();
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Neuer Pin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            maxLines: 4,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Was möchtest du teilen?',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contact,
            decoration: const InputDecoration(
              hintText: 'Kontakt (optional)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: BoardCategoryConfig.all.map((c) {
              final selected = _category == c.value;
              return ChoiceChip(
                label: Text('${c.emoji} ${c.label}'),
                selected: selected,
                onSelected: (_) => setState(() => _category = c.value),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: _colors
                .map(
                  (col) => Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _color = col),
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: BoardColors.forName(col).bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _color == col
                                ? AppColors.ink800
                                : BoardColors.forName(col).border,
                            width: _color == col ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () {
                if (_content.text.trim().isEmpty) return;
                Navigator.of(context).pop(
                  _NewPost(
                    content: _content.text.trim(),
                    category: _category,
                    color: _color,
                    contact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary500),
              child: const Text('Pinnen'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-Sheet mit dem vollen Aushang-Inhalt: Bild, Text, Kontakt-Info,
/// Author, plus Delete-Aktion wenn der User der Autor ist.
class _BoardDetailSheet extends ConsumerStatefulWidget {
  const _BoardDetailSheet({required this.post});
  final BoardPost post;

  @override
  ConsumerState<_BoardDetailSheet> createState() => _BoardDetailSheetState();
}

class _BoardDetailSheetState extends ConsumerState<_BoardDetailSheet> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aushang löschen?'),
        content: const Text('Andere User sehen den Aushang nicht mehr.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.emergency500),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(boardRepositoryProvider).delete(widget.post.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
      );
      setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final colors = BoardColors.forName(post.color);
    final cat = post.categoryConfig;
    final myId = sb.auth.currentUser?.id;
    final isMine = myId != null && myId == post.authorId;
    final fullDate =
        DateFormat('d. MMMM yyyy · HH:mm', 'de').format(post.createdAt);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                color: colors.bg,
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.label,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (post.pinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.push_pin,
                            size: 16, color: colors.text),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: colors.text,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (post.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          post.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 100,
                            color: AppColors.stone100,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image,
                                color: AppColors.stone400),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      post.content,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.ink800,
                      ),
                    ),
                    if (post.contactInfo != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary500.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.alternate_email,
                                size: 16, color: AppColors.primary500),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText(
                                post.contactInfo!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.ink400),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            post.authorName ?? 'Unbekannt',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink700,
                            ),
                          ),
                        ),
                        Text(
                          fullDate,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.ink400,
                          ),
                        ),
                      ],
                    ),
                    if (isMine) ...[
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _deleting ? null : _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.emergency500,
                          side: const BorderSide(
                              color: AppColors.emergency500),
                        ),
                        icon: _deleting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline),
                        label: Text(_deleting
                            ? 'Lösche…'
                            : 'Aushang löschen'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
