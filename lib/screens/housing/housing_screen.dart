import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/empty_state.dart';

class HousingScreen extends ConsumerStatefulWidget {
  const HousingScreen({super.key});
  @override ConsumerState<HousingScreen> createState() => _HousingScreenState();
}

class _HousingScreenState extends ConsumerState<HousingScreen> {
  List<Post> _posts = [];
  bool _loading = true;
  String _search = '';

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final posts = await ref.read(postServiceProvider).getPosts(type: 'housing', search: _search.isNotEmpty ? _search : null);
      if (mounted) setState(() => _posts = posts);
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏠 Wohnen')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          decoration: InputDecoration(hintText: 'Suchen...', prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), filled: true, fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          onSubmitted: (v) { _search = v; _load(); },
        )),
        Expanded(child: RefreshIndicator(onRefresh: _load, child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
            ? EmptyState(icon: Icons.inbox_outlined, title: 'Keine Beiträge', message: 'Hier gibt es noch keine Beiträge.')
            : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _posts.length,
                itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12),
                  child: PostCard(post: _posts[i], onTap: () => context.push('/dashboard/posts/${_posts[i].id}')))))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/dashboard/create'), icon: const Icon(Icons.add), label: const Text('Erstellen')),
    );
  }
}
