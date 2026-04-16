import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/badge_widget.dart';
import 'package:mensaena/widgets/trust_score_badge.dart';
import 'package:mensaena/models/post.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beitrag'),
        actions: [
          IconButton(
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_outline),
            onPressed: () => _toggleSave(userId),
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(),
          ),
        ],
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (post) {
          if (post == null) {
            return const Center(child: Text('Beitrag nicht gefunden'));
          }
          return _buildDetail(context, post, userId);
        },
      ),
    );
  }

  Widget _buildDetail(BuildContext context, Post post, String? userId) {
    final isOwner = userId == post.userId;
    final postType = post.postType;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Images
          if (post.allImages.isNotEmpty)
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: post.allImages.length,
                itemBuilder: (_, i) => CachedNetworkImage(
                  imageUrl: post.allImages[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Badge
                AppBadge(
                  label: '${postType.emoji} ${postType.label}',
                  color: AppColors.primary500,
                ),
                const SizedBox(height: 12),

                // Title
                Text(post.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                // Author
                GestureDetector(
                  onTap: () => context.push('/dashboard/profile/${post.userId}'),
                  child: Row(
                    children: [
                      AvatarWidget(
                        imageUrl: post.authorAvatarUrl,
                        name: post.authorName,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(timeago.format(post.createdAt, locale: 'de'), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      if (post.profile != null)
                        TrustScoreBadge(
                          score: (post.profile!['trust_score'] as num?)?.toDouble() ?? 0,
                          size: TrustBadgeSize.small,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Description
                if (post.description != null && post.description!.isNotEmpty) ...[
                  Text(post.description!, style: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                ],

                // Location
                if (post.locationText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: AppColors.primary500),
                        const SizedBox(width: 8),
                        Expanded(child: Text(post.locationText!, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Tags
                if (post.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: post.tags.map((tag) => Chip(
                      label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                      backgroundColor: AppColors.primary50,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Contact Section
                if (!isOwner) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('Kontakt aufnehmen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (userId == null) return;
                            final chatService = ref.read(postServiceProvider);
                            // Navigate to DM
                            context.push('/dashboard/messages');
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('Nachricht'),
                        ),
                      ),
                      if (post.contactPhone != null) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: const Text('Anrufen'),
                        ),
                      ],
                    ],
                  ),
                ],

                // Owner Actions
                if (isOwner) ...[
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('Beitrag verwalten', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (post.status == 'active')
                        OutlinedButton.icon(
                          onPressed: () => _updateStatus(post.id, 'fulfilled'),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Erledigt'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _updateStatus(post.id, 'archived'),
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: const Text('Archivieren'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _deletePost(post.id),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Löschen'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSave(String? userId) async {
    if (userId == null) return;
    final service = ref.read(postServiceProvider);
    try {
      if (_isSaved) {
        await service.unsavePost(widget.postId, userId);
      } else {
        await service.savePost(widget.postId, userId);
      }
      setState(() => _isSaved = !_isSaved);
    } catch (_) {}
  }

  void _share() {
    SharePlus.instance.share(ShareParams(text: 'Schau dir diesen Beitrag auf Mensaena an!'));
  }

  Future<void> _updateStatus(String postId, String status) async {
    try {
      await ref.read(postServiceProvider).updateStatus(postId, status);
      ref.invalidate(postDetailProvider(postId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status auf "$status" geändert')),
        );
      }
    } catch (_) {}
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beitrag löschen?'),
        content: const Text('Dieser Vorgang kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(postServiceProvider).deletePost(postId);
      if (mounted) context.pop();
    }
  }
}
