import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/models/post.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/trust_score_badge.dart';

class PostCard extends ConsumerWidget {
  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onSave;
  final VoidCallback? onContact;
  final bool isSaved;
  final bool showActions;

  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onSave,
    this.onContact,
    this.isSaved = false,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postType = post.postType;
    final isCritical = post.urgency == 'critical' || post.urgency == 'high';
    final isUrgent = post.urgency == 'medium';
    final accentColor = isCritical
        ? AppColors.emergency
        : isUrgent
            ? const Color(0xFFF97316) // orange-500
            : _getTypeColor(postType);

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context, ref),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
            right: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
            left: BorderSide(
              color: isCritical
                  ? AppColors.emergency
                  : isUrgent
                      ? const Color(0xFFF97316)
                      : AppColors.border.withValues(alpha: 0.6),
              width: isCritical || isUrgent ? 4 : 1,
            ),
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colored accent line (3px, gradient per post type / urgency)
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.2)],
                ),
              ),
            ),

            // Urgency banner (critical/high)
            if (isCritical)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: const Row(
                  children: [
                    Text('🚨', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'Kritisch – Sofortige Hilfe nötig',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (isUrgent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: const Row(
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'Dringend',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Images
            if (post.allImages.isNotEmpty) _buildImageSection(),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Author + Type Badge
                  Row(
                    children: [
                      AvatarWidget(
                        imageUrl: post.authorAvatarUrl,
                        name: post.authorName,
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              timeago.format(post.createdAt, locale: 'de'),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getTypeColor(postType).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getTypeColor(postType).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '${postType.emoji} ${postType.label}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _getTypeColor(postType)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Description
                  if (post.description != null && post.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      post.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Location
                  if (post.locationText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            post.locationText!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Tags
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: post.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#$tag',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Actions
                  if (showActions) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ActionButton(
                          icon: isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          label: 'Merken',
                          isActive: isSaved,
                          onTap: onSave,
                        ),
                        const SizedBox(width: 16),
                        _ActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'Kontakt',
                          onTap: onContact,
                        ),
                        const Spacer(),
                        if (post.profile != null) ...[
                          TrustScoreBadge(
                            score: (post.profile!['trust_score'] as num?)
                                    ?.toDouble() ??
                                0,
                            size: TrustBadgeSize.small,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwner = currentUserId != null && post.userId == currentUserId;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline),
              title: Text(isSaved ? 'Gespeichert' : 'Speichern'),
              onTap: () { Navigator.pop(ctx); onSave?.call(); },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Teilen'),
              onTap: () {
                Navigator.pop(ctx);
                Share.share('${post.title}\nhttps://www.mensaena.de/dashboard/posts/${post.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Kontakt aufnehmen'),
              onTap: () { Navigator.pop(ctx); _showContactModal(context, ref); },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.warning),
              title: const Text('Melden'),
              onTap: () {
                Navigator.pop(ctx);
                _reportPost(context, ref);
              },
            ),
            if (isOwner) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Bearbeiten'),
                onTap: () { Navigator.pop(ctx); context.push('/dashboard/posts/${post.id}/edit'); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Löschen', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Beitrag löschen?'),
                      content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
                        TextButton(onPressed: () => Navigator.pop(c, true), style: TextButton.styleFrom(foregroundColor: AppColors.error), child: const Text('Löschen')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await ref.read(supabaseProvider).from('posts').delete().eq('id', post.id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beitrag gelöscht')));
                    } catch (_) {}
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showContactModal(BuildContext context, WidgetRef ref) {
    final msgCtrl = TextEditingController(text: 'Hallo, ich interessiere mich für deinen Beitrag "${post.title}".');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kontakt aufnehmen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Nachricht an ${post.authorName}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Deine Nachricht...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final userId = ref.read(currentUserIdProvider);
                  if (userId == null) return;
                  Navigator.pop(ctx);
                  try {
                    final client = ref.read(supabaseProvider);
                    final dm = await client.rpc('open_or_create_dm', params: {'p_user_id': userId, 'p_other_user_id': post.userId});
                    final convId = dm is Map ? dm['id'] as String? : dm?.toString();
                    if (convId != null) {
                      await client.from('messages').insert({
                        'conversation_id': convId,
                        'sender_id': userId,
                        'content': msgCtrl.text.trim(),
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nachricht gesendet')));
                      }
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fehler beim Senden')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary500, foregroundColor: Colors.white),
                child: const Text('Nachricht senden'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reportPost(BuildContext context, WidgetRef ref) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    String? reason;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beitrag melden'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Warum möchtest du diesen Beitrag melden?', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            ...['Spam', 'Unangemessener Inhalt', 'Falsche Informationen', 'Sonstiges'].map((r) => RadioListTile<String>(
              title: Text(r, style: const TextStyle(fontSize: 14)),
              value: r,
              groupValue: reason,
              dense: true,
              onChanged: (v) { reason = v; (ctx as Element).markNeedsBuild(); },
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (reason == null) return;
              try {
                await ref.read(supabaseProvider).from('content_reports').insert({
                  'reporter_id': userId, 'content_type': 'post', 'content_id': post.id, 'reason': reason,
                });
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beitrag gemeldet. Danke!')));
              } catch (_) {}
            },
            child: const Text('Melden'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final images = post.allImages;
    if (images.isEmpty) return const SizedBox.shrink();

    Widget imageWidget;
    if (images.length == 1) {
      imageWidget = SizedBox(
        height: 200,
        width: double.infinity,
        child: _cachedImage(images[0]),
      );
    } else if (images.length == 2) {
      imageWidget = SizedBox(
        height: 160,
        child: Row(
          children: [
            Expanded(child: _cachedImage(images[0])),
            const SizedBox(width: 2),
            Expanded(child: _cachedImage(images[1])),
          ],
        ),
      );
    } else if (images.length == 3) {
      imageWidget = SizedBox(
        height: 180,
        child: Row(
          children: [
            Expanded(flex: 2, child: _cachedImage(images[0])),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _cachedImage(images[1])),
                  const SizedBox(height: 2),
                  Expanded(child: _cachedImage(images[2])),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      imageWidget = SizedBox(
        height: 200,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _cachedImage(images[0])),
                  const SizedBox(width: 2),
                  Expanded(child: _cachedImage(images[1])),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _cachedImage(images[2])),
                  const SizedBox(width: 2),
                  Expanded(child: _cachedImage(images[3])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: imageWidget,
    );
  }

  Widget _cachedImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(
        color: AppColors.borderLight,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.borderLight,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }

  Color _getTypeColor(PostType type) {
    return Color(type.colorValue);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.primary500 : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? AppColors.primary500 : AppColors.textMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
