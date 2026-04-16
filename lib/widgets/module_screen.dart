import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class ModuleScreen extends ConsumerStatefulWidget {
  final String title;
  final String emoji;
  final String description;
  final List<String> filterTypes;
  final List<String> defaultTabs;
  final Future<List<Post>> Function({String? search, String? tab}) loadPosts;
  final VoidCallback? onCreatePost;
  final Widget? headerWidget;

  const ModuleScreen({
    super.key,
    required this.title,
    required this.emoji,
    required this.description,
    this.filterTypes = const [],
    this.defaultTabs = const ['Alle', 'Suche', 'Biete'],
    required this.loadPosts,
    this.onCreatePost,
    this.headerWidget,
  });

  @override
  ConsumerState<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends ConsumerState<ModuleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.defaultTabs.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tab = widget.defaultTabs[_tabController.index];
      final posts = await widget.loadPosts(
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        tab: tab,
      );
      if (mounted) setState(() => _posts = posts);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.emoji} ${widget.title}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Suchen...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadData();
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
                  onSubmitted: (_) => _loadData(),
                ),
              ),

              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary500,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary500,
                tabs: widget.defaultTabs
                    .map((t) => Tab(text: t))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary500,
        child: _buildBody(),
      ),
      floatingActionButton: widget.onCreatePost != null
          ? FloatingActionButton.extended(
              onPressed: widget.onCreatePost,
              icon: const Icon(Icons.add),
              label: const Text('Erstellen'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingSkeleton(type: SkeletonType.postList);
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Fehler beim Laden', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadData, child: const Text('Erneut versuchen')),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Keine Beiträge',
        message: 'Hier gibt es noch keine Beiträge in dieser Kategorie.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _posts.length + (widget.headerWidget != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (widget.headerWidget != null && index == 0) {
          return widget.headerWidget!;
        }
        final postIndex =
            widget.headerWidget != null ? index - 1 : index;
        final post = _posts[postIndex];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PostCard(
            post: post,
            onTap: () {
              // Navigate to post detail
            },
          ),
        );
      },
    );
  }
}
