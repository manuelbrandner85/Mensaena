import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/empty_state.dart';

class MentalSupportScreen extends ConsumerStatefulWidget {
  const MentalSupportScreen({super.key});

  @override
  ConsumerState<MentalSupportScreen> createState() => _MentalSupportScreenState();
}

class _MentalSupportScreenState extends ConsumerState<MentalSupportScreen> {
  List<Post> _posts = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final posts = await ref.read(postServiceProvider).getPosts(
        type: 'mental',
        search: _search.isNotEmpty ? _search : null,
      );
      if (mounted) setState(() => _posts = posts);
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mentale Unterstuetzung')),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.favorite_outline, color: AppColors.primary500),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Du bist nicht allein. Hier findest du Unterstuetzung und Austausch zu mentaler Gesundheit.',
                    style: TextStyle(fontSize: 13, color: AppColors.primary700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (v) { _search = v; _load(); },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary500,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _posts.isEmpty
                      ? const EmptyState(
                          icon: Icons.psychology_outlined,
                          title: 'Keine Beitraege',
                          message: 'Hier gibt es noch keine Beitraege zur mentalen Unterstuetzung.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _posts.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PostCard(
                              post: _posts[i],
                              onTap: () => context.push('/dashboard/posts/${_posts[i].id}'),
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
        label: const Text('Erstellen'),
      ),
    );
  }
}
