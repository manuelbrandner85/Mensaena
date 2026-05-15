import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_avatar.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../core/widgets/kategorie_chip.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase/database_service.dart';
import '../../services/supabase/supabase_service.dart';

final postDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) {
  return db.getPost(id);
});

final postCommentsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, postId) {
  return supabase.client
      .from('post_comments')
      .stream(primaryKey: ['id'])
      .eq('post_id', postId)
      .order('created_at');
});

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider);
    if (user == null || _comment.text.trim().isEmpty) return;
    try {
      await supabase.client.from('post_comments').insert({
        'post_id': widget.postId,
        'user_id': user.id,
        'content': _comment.text.trim(),
      });
      _comment.clear();
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(context, variant: ToastVariant.error, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(postDetailProvider(widget.postId));
    final comments = ref.watch(postCommentsProvider(widget.postId));

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'BEITRAG'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  post.when(
                    loading: () => const CinemaLoadingSkeleton(),
                    error: (e, _) => Text('$e'),
                    data: (p) => p == null
                        ? Text(
                            'Beitrag nicht gefunden.',
                            style: MnTypography.body(),
                          )
                        : _PostHeader(post: p),
                  ),
                  const SizedBox(height: 24),
                  Text('Kommentare', style: MnTypography.label()),
                  const SizedBox(height: 12),
                  comments.when(
                    loading: () =>
                        const CinemaLoadingSkeleton(variant: SkeletonVariant.text),
                    error: (e, _) => Text('$e'),
                    data: (cs) => Column(
                      children:
                          cs.map((c) => _CommentTile(comment: c)).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: MnColors.surface,
                border: Border(top: BorderSide(color: MnColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CinemaInput(
                      controller: _comment,
                      placeholder: 'Kommentar schreiben...',
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlowButton(
                    label: '',
                    icon: LucideIcons.send,
                    compact: true,
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = (post['profiles'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final kat = PostKategorie.values
        .where((k) => k.name == (post['type'] as String?))
        .firstOrNull;
    final url = post['image_url'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kat != null) ...[
            KategorieChip(kategorie: kat),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              CinemaAvatar(
                imageUrl: author['avatar_url'] as String?,
                displayName: author['full_name'] as String?,
                size: AvatarSize.lg,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (author['full_name'] as String?) ?? 'Nachbar*in',
                  style: MnTypography.body(weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if ((post['title'] as String?)?.isNotEmpty == true) ...[
            Text(post['title'] as String, style: MnTypography.display(size: 22)),
            const SizedBox(height: 8),
          ],
          Text((post['content'] as String?) ?? '', style: MnTypography.body(size: 16)),
          if (url != null && url.isNotEmpty) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CinemaAvatar(size: AvatarSize.sm),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (comment['user_name'] as String?) ?? 'Nachbar*in',
                  style: MnTypography.body(
                    weight: FontWeight.w600,
                    color: MnColors.ink,
                    size: 13,
                  ),
                ),
                Text(
                  (comment['content'] as String?) ?? '',
                  style: MnTypography.body(color: MnColors.inkSoft, size: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
