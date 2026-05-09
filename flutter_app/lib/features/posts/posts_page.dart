import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import 'models.dart';
import 'posts_repository.dart';

class PostsPage extends ConsumerStatefulWidget {
  const PostsPage({super.key, this.title = 'Hilfe-Posts', this.initialType = 'all', this.lockType = false});
  final String title;
  final String initialType;

  /// Wenn true, wird die Type-Filter-Leiste ausgeblendet (z. B. für
  /// themed-Wrapper wie /dashboard/sharing).
  final bool lockType;

  @override
  ConsumerState<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends ConsumerState<PostsPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  late String _filter = widget.initialType;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _page = 0;
      _hasMore = true;
    });
    try {
      final list = await ref.read(postsRepositoryProvider).list(
            typeFilter: _filter,
            search: _search,
          );
      if (!mounted) return;
      setState(() {
        _posts = list;
        _loading = false;
        _hasMore = list.length >= 20;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final list = await ref.read(postsRepositoryProvider).list(
            typeFilter: _filter,
            search: _search,
            page: next,
          );
      if (!mounted) return;
      setState(() {
        _posts = [..._posts, ...list];
        _page = next;
        _loadingMore = false;
        _hasMore = list.length >= 20;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = value);
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Erstellen',
            onPressed: () =>
                context.go('${Routes.dashboardCreate}?type=post'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Suchen…',
                prefixIcon: const Icon(Icons.search, size: 20),
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
          // Type filter (ausgeblendet wenn lockType=true)
          if (!widget.lockType)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: PostTypeConfig.filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final f = PostTypeConfig.filters[i];
                  final selected = _filter == f.value;
                  return ChoiceChip(
                    label: Text(f.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _filter = f.value);
                      _load();
                    },
                    selectedColor: AppColors.primary500.withValues(alpha: 0.15),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _posts.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (i >= _posts.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return PostListTile(post: _posts[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class PostListTile extends StatelessWidget {
  const PostListTile({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final cfg = post.typeConfig;
    final time = DateFormat('d. MMM, HH:mm', 'de').format(post.createdAt);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go('${Routes.dashboardPosts}/${post.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cfg.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${cfg.emoji} ${cfg.label}',
                      style: TextStyle(
                        color: cfg.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if ((post.urgency ?? 0) >= 3)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Dringend',
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: const TextStyle(
                      color: AppColors.ink400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              if ((post.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  post.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              if (post.locationText != null || post.author != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (post.locationText != null) ...[
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.ink400,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          post.locationText!,
                          style: const TextStyle(
                            color: AppColors.ink400,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (post.author != null && !post.isAnonymous)
                      Text(
                        post.author!.displayName(),
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 12,
                        ),
                      )
                    else if (post.isAnonymous)
                      const Text(
                        'Anonym',
                        style: TextStyle(
                          color: AppColors.ink400,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📭', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'Keine Posts gefunden',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Probiere einen anderen Filter oder erstelle den ersten Post.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink400, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
