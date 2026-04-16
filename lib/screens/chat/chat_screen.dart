import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary500,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary500,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.person_outline, size: 20),
              text: 'Direktnachrichten',
            ),
            Tab(
              icon: Icon(Icons.forum_outlined, size: 20),
              text: 'Community',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DirectMessagesTab(),
          _CommunityChannelsTab(),
        ],
      ),
    );
  }
}

// ─── DM Tab ───────────────────────────────────────────────────────────────────

class _DirectMessagesTab extends ConsumerWidget {
  const _DirectMessagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(conversationsProvider),
      color: AppColors.primary500,
      child: conversationsAsync.when(
        loading: () => const LoadingSkeleton(type: SkeletonType.chat),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
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
          // Filter to only show direct conversations
          final dmConversations = conversations.where((conv) {
            final convData =
                conv['conversations'] as Map<String, dynamic>? ?? {};
            final type = convData['type'] as String? ?? conv['type'] as String? ?? 'direct';
            return type == 'direct';
          }).toList();

          if (dmConversations.isEmpty) {
            return const EmptyState(
              icon: Icons.mail_outline,
              title: 'Keine Nachrichten',
              message:
                  'Du hast noch keine Unterhaltungen. Kontaktiere jemanden zu einem Beitrag!',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: dmConversations.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final conv = dmConversations[index];
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
    );
  }
}

// ─── Community Tab ────────────────────────────────────────────────────────────

class _CommunityChannelsTab extends ConsumerWidget {
  const _CommunityChannelsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(chatChannelsProvider);
    final conversationsAsync = ref.watch(conversationsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(chatChannelsProvider);
        ref.invalidate(conversationsProvider);
      },
      color: AppColors.primary500,
      child: channelsAsync.when(
        loading: () => const LoadingSkeleton(type: SkeletonType.chat),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Fehler: $e'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(chatChannelsProvider),
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
        data: (channels) {
          // Also include group conversations from user's conversations
          final groupConversations = conversationsAsync.when(
            data: (conversations) => conversations.where((conv) {
              final convData =
                  conv['conversations'] as Map<String, dynamic>? ?? {};
              final type = convData['type'] as String? ?? conv['type'] as String? ?? 'direct';
              return type == 'group' || type == 'system';
            }).toList(),
            loading: () => <Map<String, dynamic>>[],
            error: (_, __) => <Map<String, dynamic>>[],
          );

          if (channels.isEmpty && groupConversations.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'Keine Channels',
              message:
                  'Es gibt noch keine Community-Channels. Bald gibt es hier Austausch fuer alle!',
            );
          }

          final totalItems = channels.length + groupConversations.length;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: totalItems,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index < channels.length) {
                final channel = channels[index];
                return _ChannelTile(
                  channel: channel,
                  onTap: () {
                    final id = channel['id'] as String? ??
                        channel['conversation_id'] as String?;
                    if (id != null) {
                      context.push('/dashboard/chat/$id');
                    }
                  },
                );
              } else {
                final conv = groupConversations[index - channels.length];
                return _ConversationTile(
                  conversation: conv,
                  isGroup: true,
                  onTap: () {
                    final convId = conv['conversation_id'] as String? ??
                        (conv['conversations']
                            as Map<String, dynamic>?)?['id'] as String?;
                    if (convId != null) {
                      context.push('/dashboard/chat/$convId');
                    }
                  },
                );
              }
            },
          );
        },
      ),
    );
  }
}

// ─── Tiles ────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;
  final bool isGroup;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    final conv = conversation['conversations'] as Map<String, dynamic>?;
    final title = conv?['title'] as String? ?? 'Unterhaltung';
    final type =
        conv?['type'] as String? ?? conversation['type'] as String? ?? 'direct';
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
            name: title,
            size: 48,
          ),
          if (type == 'group' || isGroup)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group,
                  size: 14,
                  color: AppColors.trust,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
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

class _ChannelTile extends StatelessWidget {
  final Map<String, dynamic> channel;
  final VoidCallback onTap;
  const _ChannelTile({required this.channel, required this.onTap});

  IconData _getChannelIcon(String? category) {
    switch (category) {
      case 'general':
        return Icons.tag;
      case 'help':
        return Icons.volunteer_activism;
      case 'events':
        return Icons.event;
      case 'marketplace':
        return Icons.storefront;
      case 'crisis':
        return Icons.warning_amber;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = channel['name'] as String? ?? 'Channel';
    final description = channel['description'] as String?;
    final category = channel['category'] as String?;
    final memberCount = channel['member_count'] as int?;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_getChannelIcon(category), color: AppColors.primary500),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: description != null
          ? Text(
              description,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (memberCount != null) ...[
            Text(
              '$memberCount',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const Text(
              'Mitglieder',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
          const Icon(Icons.chevron_right,
              color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
