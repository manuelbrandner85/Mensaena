import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class RescuerScreen extends ConsumerStatefulWidget {
  const RescuerScreen({super.key});

  @override
  ConsumerState<RescuerScreen> createState() => _RescuerScreenState();
}

class _RescuerScreenState extends ConsumerState<RescuerScreen> {
  final _searchController = TextEditingController();
  List<Post> _posts = [];
  bool _loading = true;
  String _selectedCategory = 'Alle';

  static const _categories = [
    'Alle',
    'Hilfe angeboten',
    'Hilfe gesucht',
    'Notfall',
    'Erste Hilfe',
    'Ehrenamt',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(postServiceProvider);
      final cat = _selectedCategory != 'Alle' ? _selectedCategory.toLowerCase() : null;
      final search = _searchController.text.isNotEmpty ? _searchController.text : null;
      final results = await Future.wait([
        service.getPosts(type: 'rescue', category: cat, search: search),
        service.getPosts(type: 'sharing', category: cat, search: search),
      ]);
      final posts = [...results[0], ...results[1]];
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _posts = posts);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\u{1F691} Rettungsnetz'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: AppColors.surface,
            child: const Text(
              'Nachbarschaftliches Rettungsnetz: Hilfe anbieten, Helfer finden und im Notfall fuereinander da sein.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                          _load();
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                filled: true,
                fillColor: AppColors.background,
              ),
              onSubmitted: (_) => _load(),
              onChanged: (v) => setState(() {}),
            ),
          ),

          // Category filter chips
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                return FilterChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedCategory = cat);
                    _load();
                  },
                  selectedColor: AppColors.primary500,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color:
                          isSelected ? AppColors.primary500 : AppColors.border,
                    ),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Post list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary500,
              child: _loading
                  ? const LoadingSkeleton(type: SkeletonType.postList)
                  : _posts.isEmpty
                      ? const EmptyState(
                          icon: Icons.health_and_safety_outlined,
                          title: 'Noch keine Helfer',
                          message:
                              'Das Rettungsnetz ist noch leer. Biete deine Hilfe an und werde Teil des nachbarschaftlichen Rettungsnetzes!',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _posts.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PostCard(
                              post: _posts[i],
                              onTap: () => context
                                  .push('/dashboard/posts/${_posts[i].id}'),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/create'),
        icon: const Icon(Icons.add),
        label: const Text('Hilfe anbieten'),
      ),
    );
  }
}
