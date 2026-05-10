import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../messages/messages_repository.dart';
import 'models.dart';
import 'post_reactions_widget.dart';
import 'posts_repository.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

enum _PostMenuAction { report }

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  Post? _post;
  bool _loading = true;
  bool _isSaved = false;
  bool _saveBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(postsRepositoryProvider);
      final p = await repo.fetch(widget.postId);
      if (!mounted) return;
      if (p == null) {
        setState(() {
          _error = 'Post nicht gefunden';
          _loading = false;
        });
        return;
      }
      final saved = await repo.savedPostIds();
      if (!mounted) return;
      setState(() {
        _post = p;
        _isSaved = saved.contains(p.id);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleSave() async {
    final post = _post;
    if (post == null || _saveBusy) return;
    setState(() => _saveBusy = true);
    try {
      final saved =
          await ref.read(postsRepositoryProvider).toggleSavedPost(post.id);
      if (!mounted) return;
      setState(() => _isSaved = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved ? 'Gemerkt' : 'Aus Merkliste entfernt'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _saveBusy = false);
    }
  }

  Future<void> _sharePost() async {
    final post = _post;
    if (post == null) return;
    final url = 'https://www.mensaena.de/dashboard/posts/${post.id}';
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      '${post.title}\n\n$url',
      subject: post.title,
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  Future<void> _reportPost() async {
    final post = _post;
    if (post == null) return;
    final reason = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        const reasons = [
          'Spam',
          'Beleidigung / Hass',
          'Sexueller Inhalt',
          'Falsche Informationen',
          'Sonstiges',
        ];
        String? selected;
        final controller = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setSheetState) => AlertDialog(
            title: const Text('Post melden'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in reasons)
                    RadioListTile<String>(
                      value: r,
                      groupValue: selected,
                      title: Text(r),
                      onChanged: (v) => setSheetState(() => selected = v),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  if (selected == 'Sonstiges')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: controller,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'Was stört dich an dem Post?',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () {
                        final r = selected == 'Sonstiges'
                            ? controller.text.trim().isEmpty
                                ? 'Sonstiges'
                                : controller.text.trim()
                            : selected!;
                        Navigator.pop(ctx, r);
                      },
                child: const Text('Melden'),
              ),
            ],
          ),
        );
      },
    );
    if (reason == null || !mounted) return;
    try {
      await ref.read(postsRepositoryProvider).reportPost(
            postId: post.id,
            reason: reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Danke — die Moderatoren prüfen den Beitrag.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = '$e'.contains('content_reports_unique')
          ? 'Du hast diesen Post bereits gemeldet.'
          : 'Melden fehlgeschlagen: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  Future<void> _contactAuthor() async {
    final post = _post;
    if (post == null) return;
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;
    if (myId == null || myId == post.userId) return;
    try {
      final convId = await ref
          .read(messagesRepositoryProvider)
          .findOrCreateDirectConversation(
            userA: myId,
            userB: post.userId,
          );
      if (!mounted) return;
      context.go('${Routes.dashboardChat}?conv=$convId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte Chat nicht öffnen: $e')),
      );
    }
  }

  Future<void> _launch(String uri) async {
    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (post != null) ...[
            IconButton(
              tooltip: _isSaved ? 'Aus Merkliste entfernen' : 'Merken',
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? AppColors.primary500 : null,
              ),
              onPressed: _saveBusy ? null : _toggleSave,
            ),
            IconButton(
              tooltip: 'Teilen',
              icon: const Icon(Icons.share_outlined),
              onPressed: _sharePost,
            ),
            PopupMenuButton<_PostMenuAction>(
              tooltip: 'Mehr',
              icon: const Icon(Icons.more_vert),
              onSelected: (a) {
                if (a == _PostMenuAction.report) _reportPost();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _PostMenuAction.report,
                  child: ListTile(
                    leading: Icon(Icons.flag_outlined,
                        color: AppColors.emergency500,),
                    title: Text('Melden',
                        style: TextStyle(color: AppColors.emergency500),),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(_post!),
    );
  }

  Widget _buildBody(Post post) {
    final cfg = post.typeConfig;
    final fullDate = DateFormat('d. MMMM yyyy · HH:mm', 'de').format(post.createdAt);
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;
    final isMine = myId == post.userId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cfg.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${cfg.emoji} ${cfg.label}',
              style: TextStyle(
                color: cfg.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            post.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          // Author + date
          Row(
            children: [
              if (post.author?.avatarUrl != null)
                CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage(post.author!.avatarUrl!),
                )
              else
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
                  child: Text(
                    (post.author?.displayName() ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                post.isAnonymous ? 'Anonym' : (post.author?.displayName() ?? 'Unbekannt'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Text(' · ', style: TextStyle(color: AppColors.ink400)),
              Text(
                fullDate,
                style: const TextStyle(color: AppColors.ink400, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          if ((post.description ?? '').isNotEmpty)
            Text(
              post.description!,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          // Media
          if (post.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: post.mediaUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.mediaUrls[i],
                    width: 240,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 240,
                      height: 180,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: AppColors.ink400),
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Tags
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: post.tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary500.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$t',
                        style: const TextStyle(
                          color: AppColors.primary500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          // Reactions
          PostReactionsWidget(postId: post.id),
          const SizedBox(height: 16),
          // Meta block
          _MetaCard(post: post, onLaunch: _launch),
          // Actions
          if (!isMine) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _contactAuthor,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Anschreiben'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.post, required this.onLaunch});
  final Post post;
  final ValueChanged<String> onLaunch;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (post.locationText != null) {
      rows.add(_metaRow(Icons.location_on_outlined, 'Ort', post.locationText!));
    }
    if ((post.urgency ?? 0) > 0) {
      rows.add(
        _metaRow(
          Icons.priority_high,
          'Dringlichkeit',
          'Stufe ${post.urgency}',
        ),
      );
    }
    if (post.contactPhone != null && !post.privacyPhone) {
      rows.add(
        _metaRow(
          Icons.phone_outlined,
          'Telefon',
          post.contactPhone!,
          onTap: () => onLaunch('tel:${post.contactPhone}'),
        ),
      );
    }
    if (post.contactEmail != null && !post.privacyEmail) {
      rows.add(
        _metaRow(
          Icons.mail_outline,
          'E-Mail',
          post.contactEmail!,
          onTap: () => onLaunch('mailto:${post.contactEmail}'),
        ),
      );
    }
    if (post.contactWhatsapp != null) {
      rows.add(
        _metaRow(
          Icons.chat,
          'WhatsApp',
          post.contactWhatsapp!,
          onTap: () => onLaunch('https://wa.me/${post.contactWhatsapp}'),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(children: rows),
    );
  }

  Widget _metaRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.ink400),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.ink400, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: onTap != null ? FontWeight.w600 : FontWeight.w400,
                color: onTap != null ? AppColors.primary500 : AppColors.ink700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}
