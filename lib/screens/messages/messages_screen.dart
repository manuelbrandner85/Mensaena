import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nachrichten'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(conversationsProvider),
        color: AppColors.primary500,
        child: conversationsAsync.when(
          loading: () => const LoadingSkeleton(type: SkeletonType.chat),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Fehler: $e'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(conversationsProvider),
                  child: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
          data: (conversations) {
            if (conversations.isEmpty) {
              return const EmptyState(
                icon: Icons.mail_outline,
                title: 'Keine Nachrichten',
                message:
                    'Du hast noch keine Unterhaltungen. Kontaktiere jemanden zu einem Beitrag!',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: conversations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return _ConversationTile(
                  conversation: conv,
                  onTap: () {
                    final convId = conv['conversation_id'] as String? ??
                        (conv['conversations']
                            as Map<String, dynamic>?)?['id'] as String?;
                    if (convId != null) {
                      context.push('/dashboard/chat/$convId');
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;
  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final conv = conversation['conversations'] as Map<String, dynamic>?;
    final title = conv?['title'] as String?;
    final displayTitle = (title != null && title.isNotEmpty) ? title : 'Nachricht';
    final type = conv?['type'] as String? ?? 'direct';
    final otherAvatar = conv?['other_avatar'] as String?;
    final updatedAt = conv?['updated_at'] as String?;
    final lastReadAt = conversation['last_read_at'] as String?;

    // Check for unread: updated_at > last_read_at
    bool hasUnread = false;
    if (updatedAt != null && lastReadAt != null) {
      try {
        hasUnread =
            DateTime.parse(updatedAt).isAfter(DateTime.parse(lastReadAt));
      } catch (_) {}
    } else if (updatedAt != null && lastReadAt == null) {
      hasUnread = true;
    }

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          AvatarWidget(
            imageUrl: otherAvatar,
            name: displayTitle,
            size: 48,
          ),
          if (type != 'direct')
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == 'group' ? Icons.group : Icons.campaign,
                  size: 14,
                  color: AppColors.trust,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        displayTitle,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
          fontSize: 15,
          color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        type == 'direct' ? 'Direktnachricht' : 'Gruppenchat',
        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (updatedAt != null)
            Text(
              timeago.format(DateTime.parse(updatedAt), locale: 'de'),
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          if (hasUnread) ...[
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
