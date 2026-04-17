import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
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
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.sticky_note_2_outlined, size: 56, color: AppColors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text('Noch keine Beitraege', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Erstelle den ersten Aushang!', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ]))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(boardPostsProvider({'category': _category, 'search': _search.isNotEmpty ? _search : null})),
                child: GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.85),
                    itemCount: list.length, itemBuilder: (_, i) => _BoardCard(post: list[i])),
              ),
        )),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBoardPost(context),
        icon: const Icon(Icons.add),
        label: const Text('Aushang erstellen'),
      ),
    );
  }

  void _showCreateBoardPost(BuildContext context) {
    final contentCtrl = TextEditingController();
    String color = 'yellow';
    String category = 'general';
    final colors = {'yellow': const Color(0xFFFFF9C4), 'blue': const Color(0xFFBBDEFB), 'green': const Color(0xFFC8E6C9), 'pink': const Color(0xFFF8BBD0), 'orange': const Color(0xFFFFE0B2), 'purple': const Color(0xFFE1BEE7)};

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(builder: (ctx, setBS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Neuer Aushang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Inhalt *', hintText: 'Was moechtest du teilen?'), maxLines: 4, maxLength: 500),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: BoardPostCategory.values.map((c) => DropdownMenuItem(value: c.value, child: Text('${c.emoji} ${c.label}'))).toList(),
              onChanged: (v) => setBS(() => category = v ?? 'general'),
            ),
            const SizedBox(height: 12),
            const Text('Farbe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Row(children: colors.entries.map((e) => GestureDetector(
              onTap: () => setBS(() => color = e.key),
              child: Container(
                width: 36, height: 36, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(8), border: Border.all(color: color == e.key ? AppColors.primary500 : Colors.transparent, width: 2)),
              ),
            )).toList()),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () async {
                if (contentCtrl.text.trim().isEmpty) return;
                final userId = ref.read(currentUserIdProvider);
                if (userId == null) return;
                Navigator.pop(ctx);
                try {
                  await ref.read(boardServiceProvider).createBoardPost({
                    'author_id': userId, 'content': contentCtrl.text.trim(), 'category': category, 'color': color, 'status': 'active',
                  });
                  ref.invalidate(boardPostsProvider({'category': _category, 'search': _search.isNotEmpty ? _search : null}));
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aushang erstellt!')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                }
              },
              child: const Text('Aushang erstellen'),
            )),
          ],
        )),
      ),
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
        Row(children: [
          Text(post.boardCategory.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
            child: Text(post.boardCategory.label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(post.content, style: const TextStyle(fontSize: 13, height: 1.4), maxLines: 5, overflow: TextOverflow.ellipsis),
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