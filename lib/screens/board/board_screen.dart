import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/board_provider.dart';
import 'package:mensaena/models/board_post.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:timeago/timeago.dart' as timeago;

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});
  @override ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  String? _category;
  String _search = '';

  @override Widget build(BuildContext context) {
    final posts = ref.watch(boardPostsProvider({'category': _category, 'search': _search.isNotEmpty ? _search : null}));
    return Scaffold(
      appBar: AppBar(title: const Text('📌 Schwarzes Brett')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          decoration: InputDecoration(hintText: 'Suchen...', prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), filled: true, fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          onSubmitted: (v) => setState(() => _search = v),
        )),
        SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [null, ...BoardPostCategory.values].map((cat) => Padding(padding: const EdgeInsets.only(right: 8),
            child: FilterChip(label: Text(cat?.label ?? 'Alle', style: const TextStyle(fontSize: 12)),
              selected: _category == cat?.value, selectedColor: AppColors.primary100,
              onSelected: (_) => setState(() => _category = cat?.value)))).toList())),
        const SizedBox(height: 8),
        Expanded(child: posts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (list) => list.isEmpty
            ? const Center(child: Text('Keine Beiträge'))
            : GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.85),
                itemCount: list.length, itemBuilder: (_, i) => _BoardCard(post: list[i])),
        )),
      ]),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final BoardPost post;
  const _BoardCard({required this.post});
  static const _colors = {'yellow': Color(0xFFFFF9C4), 'blue': Color(0xFFBBDEFB), 'green': Color(0xFFC8E6C9), 'pink': Color(0xFFF8BBD0), 'orange': Color(0xFFFFE0B2), 'purple': Color(0xFFE1BEE7)};

  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _colors[post.color] ?? _colors['yellow'], borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(post.boardCategory.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        Text(post.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(post.content, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 3, overflow: TextOverflow.ellipsis),
        const Spacer(),
        Row(children: [
          AvatarWidget(imageUrl: post.profile?['avatar_url'] as String?, name: post.profile?['nickname'] as String? ?? '?', size: 20),
          const SizedBox(width: 6),
          Expanded(child: Text(timeago.format(post.createdAt, locale: 'de'), style: const TextStyle(fontSize: 10, color: AppColors.textMuted))),
          const Icon(Icons.push_pin, size: 14, color: AppColors.textMuted),
          Text(' ${post.pinCount}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]),
      ]));
  }
}