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

class _PostsScreenState extends ConsumerState<PostsScreen> {
  final _searchController = TextEditingController();
  String? _selectedType;

  static const _typeFilters = [
    {'value': null, 'label': 'Alle', 'emoji': '📋'},
    {'value': 'rescue', 'label': 'Hilfe', 'emoji': '🔴'},
    {'value': 'help_offered', 'label': 'Angebote', 'emoji': '🧡'},
    {'value': 'animal', 'label': 'Tiere', 'emoji': '🐾'},
    {'value': 'housing', 'label': 'Wohnen', 'emoji': '🏡'},
    {'value': 'supply', 'label': 'Versorgung', 'emoji': '🌾'},
    {'value': 'crisis', 'label': 'Notfall', 'emoji': '🚨'},
    {'value': 'mobility', 'label': 'Mobilitaet', 'emoji': '🚗'},
    {'value': 'sharing', 'label': 'Teilen', 'emoji': '🔄'},
    {'value': 'community', 'label': 'Community', 'emoji': '🗳️'},
  ];

  // Realtime
  RealtimeChannel? _realtimeChannel;
  bool _hasNewPosts = false;
  int _newPostCount = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToNewPosts();
  }

  @override
  void dispose() {
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

  Map<String, String?> get _currentParams {
    return {
      'type': _selectedType,
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
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _typeFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final f = _typeFilters[i];
                    final isSelected = _selectedType == f['value'];
                    return FilterChip(
                      label: Text('${f['emoji']} ${f['label']}', style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      )),
                      selected: isSelected,
                      selectedColor: AppColors.primary500,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: isSelected ? AppColors.primary500 : AppColors.border),
                      onSelected: (_) => setState(() => _selectedType = f['value'] as String?),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
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
