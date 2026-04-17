import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/models/board_post.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/board_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/editorial_header.dart';

const _boardColors = <String, Color>{
  'yellow': Color(0xFFFFF9C4),
  'blue': Color(0xFFBBDEFB),
  'green': Color(0xFFC8E6C9),
  'pink': Color(0xFFF8BBD0),
  'orange': Color(0xFFFFE0B2),
  'purple': Color(0xFFE1BEE7),
};

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});
  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  String? _category;
  String _search = '';
  RealtimeChannel? _channel;

  Map<String, String?> get _params =>
      {'category': _category, 'search': _search.isNotEmpty ? _search : null};

  @override
  void initState() {
    super.initState();
    _channel = ref.read(supabaseProvider).channel('board-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'board_posts',
          callback: (_) {
            if (mounted) ref.invalidate(boardPostsProvider(_params));
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(boardPostsProvider(_params));
    return Scaffold(
      appBar: AppBar(
        title: const Text('§ 04 · Aushänge'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: 'Aktualisieren',
            onPressed: () => ref.invalidate(boardPostsProvider(_params)),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: EditorialHeader(
              section: 'Aushänge',
              number: '03',
              title: 'Schwarzes Brett',
              subtitle: 'Aushänge deiner Nachbarschaft',
              icon: Icons.sticky_note_2_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [null, ...BoardPostCategory.values]
                  .map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat?.label ?? 'Alle', style: const TextStyle(fontSize: 12)),
                          selected: _category == cat?.value,
                          selectedColor: AppColors.primary100,
                          onSelected: (_) => setState(() => _category = cat?.value),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: posts.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sticky_note_2_outlined,
                              size: 56, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text('Noch keine Beiträge',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text('Erstelle den ersten Aushang!',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(boardPostsProvider(_params)),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: list.length,
                        itemBuilder: (_, i) => _BoardCard(
                          post: list[i],
                          onTap: () => _showDetail(list[i]),
                          onPinToggle: () => _togglePin(list[i]),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrEditSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Aushang erstellen'),
      ),
    );
  }

  Future<void> _togglePin(BoardPost post) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      if (post.isPinned == true) {
        await ref.read(boardServiceProvider).unpinBoardPost(post.id, userId);
      } else {
        await ref.read(boardServiceProvider).pinBoardPost(post.id, userId);
      }
      ref.invalidate(boardPostsProvider(_params));
    } catch (_) {}
  }

  void _showDetail(BoardPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scroll) => _BoardDetailSheet(
          post: post,
          scrollController: scroll,
          onDeleted: () {
            Navigator.pop(context);
            ref.invalidate(boardPostsProvider(_params));
          },
          onEdit: () {
            Navigator.pop(context);
            _showCreateOrEditSheet(existing: post);
          },
        ),
      ),
    );
  }

  void _showCreateOrEditSheet({BoardPost? existing}) {
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    final contactCtrl = TextEditingController(text: existing?.locationText ?? '');
    String color = existing?.color ?? 'yellow';
    String category = existing?.category ?? 'general';
    DateTime? expiresAt = existing?.expiresAt;
    Uint8List? newImageBytes;
    String? newImageName;
    String? currentImageUrl = existing?.imageUrl;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Neuer Aushang' : 'Aushang bearbeiten',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Inhalt *',
                    hintText: 'Was möchtest du teilen?',
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Kategorie'),
                  items: BoardPostCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c.value, child: Text('${c.emoji} ${c.label}')))
                      .toList(),
                  onChanged: (v) => setBS(() => category = v ?? 'general'),
                ),
                const SizedBox(height: 12),
                const Text('Farbe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Row(
                  children: _boardColors.entries
                      .map((e) => GestureDetector(
                            onTap: () => setBS(() => color = e.key),
                            child: Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: e.value,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: color == e.key ? AppColors.primary500 : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Kontaktinfo (optional)',
                    hintText: 'z.B. Telefon, E-Mail',
                    prefixIcon: Icon(Icons.contact_mail_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Ablaufdatum'),
                  subtitle: Text(expiresAt != null
                      ? '${expiresAt!.day}.${expiresAt!.month}.${expiresAt!.year}'
                      : 'Kein Ablauf'),
                  trailing: expiresAt != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setBS(() => expiresAt = null),
                        )
                      : null,
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: expiresAt ?? now.add(const Duration(days: 30)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) setBS(() => expiresAt = picked);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Bild hinzufügen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.textPrimary,
                      ),
                      onPressed: () async {
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1200,
                          imageQuality: 80,
                        );
                        if (picked == null) return;
                        final bytes = await picked.readAsBytes();
                        setBS(() {
                          newImageBytes = bytes;
                          newImageName = picked.name;
                          currentImageUrl = null;
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    if (newImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(newImageBytes!, width: 52, height: 52, fit: BoxFit.cover),
                      )
                    else if (currentImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: currentImageUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (contentCtrl.text.trim().isEmpty) return;
                      final userId = ref.read(currentUserIdProvider);
                      if (userId == null) return;
                      Navigator.pop(ctx);
                      try {
                        final svc = ref.read(boardServiceProvider);
                        String? imageUrl = currentImageUrl;
                        if (newImageBytes != null) {
                          imageUrl = await svc.uploadImage(
                            newImageBytes!,
                            '${DateTime.now().millisecondsSinceEpoch}_${newImageName ?? 'img.jpg'}',
                          );
                        }
                        final payload = <String, dynamic>{
                          'content': contentCtrl.text.trim(),
                          'category': category,
                          'color': color,
                          'status': 'active',
                          if (contactCtrl.text.trim().isNotEmpty)
                            'contact_info': contactCtrl.text.trim(),
                          if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
                          if (imageUrl != null) 'image_url': imageUrl,
                        };
                        if (existing == null) {
                          payload['author_id'] = userId;
                          await svc.createBoardPost(payload);
                        } else {
                          await svc.updateBoardPost(existing.id, payload);
                        }
                        ref.invalidate(boardPostsProvider(_params));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(existing == null
                                ? 'Aushang erstellt!'
                                : 'Aushang aktualisiert!'),
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Fehler: $e')));
                        }
                      }
                    },
                    child: Text(existing == null ? 'Aushang erstellen' : 'Speichern'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardCard extends ConsumerWidget {
  final BoardPost post;
  final VoidCallback onTap;
  final VoidCallback onPinToggle;
  const _BoardCard({required this.post, required this.onTap, required this.onPinToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _boardColors[post.color] ?? _boardColors['yellow'],
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x15000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(post.boardCategory.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(post.boardCategory.label,
                      style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(post.content,
                style: const TextStyle(fontSize: 13, height: 1.4),
                maxLines: 5,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            Row(
              children: [
                AvatarWidget(
                  imageUrl: post.profile?['avatar_url'] as String?,
                  name: post.profile?['name'] as String? ??
                      post.profile?['nickname'] as String? ??
                      '?',
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    timeago.format(post.createdAt, locale: 'de'),
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ),
                InkWell(
                  onTap: onPinToggle,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      post.isPinned == true
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      size: 16,
                      color: post.isPinned == true
                          ? AppColors.primary500
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                Text('${post.pinCount}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardDetailSheet extends ConsumerStatefulWidget {
  final BoardPost post;
  final ScrollController scrollController;
  final VoidCallback onDeleted;
  final VoidCallback onEdit;
  const _BoardDetailSheet({
    required this.post,
    required this.scrollController,
    required this.onDeleted,
    required this.onEdit,
  });

  @override
  ConsumerState<_BoardDetailSheet> createState() => _BoardDetailSheetState();
}

class _BoardDetailSheetState extends ConsumerState<_BoardDetailSheet> {
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _commentCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(boardServiceProvider).addComment(
            widget.post.id,
            userId,
            _commentCtrl.text.trim(),
          );
      _commentCtrl.clear();
      ref.invalidate(boardCommentsProvider(widget.post.id));
    } catch (_) {} finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmDeleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kommentar löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(boardServiceProvider).deleteComment(commentId);
      ref.invalidate(boardCommentsProvider(widget.post.id));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aushang löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(boardServiceProvider).deleteBoardPost(widget.post.id);
      widget.onDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwner = currentUserId == post.userId;
    final commentsAsync = ref.watch(boardCommentsProvider(post.id));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Text(post.boardCategory.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(post.boardCategory.label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.push_pin, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('${post.pinCount} Pins',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _boardColors[post.color] ?? _boardColors['yellow'],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(post.content, style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              AvatarWidget(
                imageUrl: post.profile?['avatar_url'] as String?,
                name: post.profile?['name'] as String? ??
                    post.profile?['nickname'] as String? ??
                    '?',
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.profile?['name'] as String? ??
                          post.profile?['nickname'] as String? ??
                          'Unbekannt',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      timeago.format(post.createdAt, locale: 'de'),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.locationText != null && post.locationText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.contact_mail_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(post.locationText!,
                      style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
          if (post.expiresAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Läuft ab am ${post.expiresAt!.day}.${post.expiresAt!.month}.${post.expiresAt!.year}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
          if (isOwner) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Bearbeiten'),
                  onPressed: widget.onEdit,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  label: const Text('Löschen', style: TextStyle(color: AppColors.error)),
                  onPressed: _confirmDelete,
                ),
              ],
            ),
          ],
          const Divider(height: 32),
          const Text('Kommentare',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          commentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Fehler: $e'),
            data: (comments) {
              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Noch keine Kommentare',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                );
              }
              return Column(
                children: comments
                    .map((c) {
                      final isOwnComment = currentUserId != null && c.userId == currentUserId;
                      return GestureDetector(
                        onLongPress: isOwnComment ? () => _confirmDeleteComment(c.id) : null,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AvatarWidget(
                                imageUrl: c.profile?['avatar_url'] as String?,
                                name: c.profile?['name'] as String? ?? c.profile?['nickname'] as String? ?? '?',
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.profile?['name'] as String? ?? c.profile?['nickname'] as String? ?? 'Unbekannt',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(timeago.format(c.createdAt, locale: 'de'), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(c.content, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              if (isOwnComment)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.textMuted),
                                  onPressed: () => _confirmDeleteComment(c.id),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Kommentar schreiben...',
                    isDense: true,
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send, color: AppColors.primary500),
                onPressed: _sending ? null : _sendComment,
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}
