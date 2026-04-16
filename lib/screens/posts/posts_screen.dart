import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final List<String> _tabs = ['Alle', 'Suche', 'Biete'];

  // Realtime
  RealtimeChannel? _realtimeChannel;
  bool _hasNewPosts = false;
  int _newPostCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _subscribeToNewPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeToNewPosts() {
    final postService = ref.read(postServiceProvider);
    _realtimeChannel = postService.subscribeToNewPosts((newPost) {
      if (mounted) {
        setState(() {
          _hasNewPosts = true;
          _newPostCount++;
        });
      }
    });
  }

  void _onNewPostsBannerTap() {
    setState(() {
      _hasNewPosts = false;
      _newPostCount = 0;
    });
    ref.invalidate(postsProvider(_currentParams));
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Map<String, String?> get _currentParams {
    String? type;
    switch (_tabController.index) {
      case 1:
        type = 'help_needed';
        break;
      case 2:
        type = 'help_offered';
        break;
    }
    return {
      'type': type,
      'search': _searchController.text.isNotEmpty
          ? _searchController.text
          : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider(_currentParams));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beitraege'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Beitraege suchen...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary500,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary500,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Realtime "new posts" banner
          if (_hasNewPosts)
            GestureDetector(
              onTap: _onNewPostsBannerTap,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppColors.primary500,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_upward,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _newPostCount == 1
                          ? '1 neuer Beitrag'
                          : '$_newPostCount neue Beitraege',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '- Tippe zum Aktualisieren',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Posts list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _hasNewPosts = false;
                  _newPostCount = 0;
                });
                ref.invalidate(postsProvider(_currentParams));
              },
              color: AppColors.primary500,
              child: postsAsync.when(
                loading: () =>
                    const LoadingSkeleton(type: SkeletonType.postList),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Fehler beim Laden',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(postsProvider(_currentParams)),
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                ),
                data: (posts) => _buildPostList(posts),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/create'),
        icon: const Icon(Icons.add),
        label: const Text('Erstellen'),
      ),
    );
  }

  Widget _buildPostList(List<Post> posts) {
    if (posts.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Keine Beitraege',
        message: 'Hier gibt es noch keine Beitraege in dieser Kategorie.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PostCard(
            post: post,
            onTap: () => context.push('/dashboard/posts/${post.id}'),
          ),
        );
      },
    );
  }
}
