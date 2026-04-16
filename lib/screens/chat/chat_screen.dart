import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/chat_provider.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelsAsync = ref.watch(chatChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Chat'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(chatChannelsProvider),
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
            if (channels.isEmpty) {
              return const EmptyState(
                icon: Icons.forum_outlined,
                title: 'Keine Channels',
                message: 'Es gibt noch keine Community-Channels.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: channels.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _ChannelTile(
                  channel: channel,
                  onTap: () {
                    final id = channel['id'] as String? ?? channel['conversation_id'] as String?;
                    if (id != null) {
                      context.push('/dashboard/chat/$id');
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
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
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
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const Text(
              'Mitglieder',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
