import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
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
  int _newPostCount = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    if (_channel != null) sb.removeChannel(_channel!);
    super.dispose();
  }

  void _subscribeRealtime() {
    final myId = sb.auth.currentUser?.id;
    _channel = sb.channel('posts-feed-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'posts',
        callback: (payload) {
          final row = payload.newRecord;
          if ((row['status'] as String?) != 'active') return;
          if (myId != null && row['user_id'] == myId) return;
          if (!mounted) return;
          setState(() => _newPostCount += 1);
        },
      )
      ..subscribe();
  }

  void _showNewPosts() {
    setState(() => _newPostCount = 0);
    _load();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _search = '');
    _load();
  }

  void _clearTypeFilter() {
    setState(() => _filter = 'all');
    _load();
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

  String _filterLabel(String value) {
    for (final f in PostTypeConfig.filters) {
      if (f.value == value) return f.label;
    }
    return value;
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
          // Active filter chips
          if (_search.isNotEmpty || (!widget.lockType && _filter != 'all'))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (_search.isNotEmpty)
                    _ActiveFilterPill(
                      icon: Icons.search,
                      label: '"$_search"',
                      color: AppColors.primary500,
                      onClear: _clearSearch,
                    ),
                  if (!widget.lockType && _filter != 'all')
                    _ActiveFilterPill(
                      icon: Icons.filter_list,
                      label: _filterLabel(_filter),
                      color: const Color(0xFF8B5CF6),
                      onClear: _clearTypeFilter,
                    ),
                ],
              ),
            ),
          // Realtime new-posts banner
          if (_newPostCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: FilledButton.icon(
                  onPressed: _showNewPosts,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(
                    _newPostCount == 1
                        ? '1 neue Post – jetzt anzeigen'
                        : '$_newPostCount neue Posts – jetzt anzeigen',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
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

class _ActiveFilterPill extends StatelessWidget {
  const _ActiveFilterPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onClear,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onClear,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.close, size: 11, color: color),
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
