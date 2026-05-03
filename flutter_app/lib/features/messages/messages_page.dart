import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/badges.dart';
import 'messages_repository.dart';
import 'models.dart';

/// Liste aller Conversations – Pendant zu /dashboard/messages (Liste-Modus
/// in ChatView.tsx, wenn keine ?conv-Param gesetzt ist).
class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncConvs = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Direktnachrichten')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(conversationsProvider.future),
        child: asyncConvs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(message: '$e', onRetry: () => ref.refresh(conversationsProvider)),
          data: (convs) {
            if (convs.isEmpty) return const _EmptyState();
            return ListView.separated(
              itemCount: convs.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
              itemBuilder: (_, i) => _ConversationTile(conversation: convs[i]),
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final last = conversation.lastMessage;
    final time = last?.createdAt ?? conversation.createdAt;
    final timeStr = _formatTime(time);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary100,
        backgroundImage: conversation.otherProfile?.avatarUrl != null
            ? NetworkImage(conversation.otherProfile!.avatarUrl!)
            : null,
        child: conversation.otherProfile?.avatarUrl == null
            ? Text(
                conversation.displayTitle().substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary700,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.displayTitle(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: AppColors.ink800,
              ),
            ),
          ),
          if (timeStr != null)
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 12,
                color: conversation.unreadCount > 0
                    ? AppColors.primary700
                    : AppColors.stone400,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                last?.isDeleted == true
                    ? 'Nachricht gelöscht'
                    : (last?.content ?? 'Noch keine Nachrichten'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: conversation.unreadCount > 0
                      ? AppColors.ink700
                      : AppColors.stone500,
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ),
            if (conversation.unreadCount > 0) ...[
              const SizedBox(width: 8),
              CountBadge(count: conversation.unreadCount),
            ],
          ],
        ),
      ),
      onTap: () =>
          context.push('${Routes.dashboardMessages}/${conversation.id}'),
    );
  }

  String? _formatTime(DateTime t) {
    final now = DateTime.now();
    final isToday = t.year == now.year && t.month == now.month && t.day == now.day;
    if (isToday) return DateFormat('HH:mm').format(t);
    final isYesterday = now.difference(t).inDays == 1;
    if (isYesterday) return 'Gestern';
    if (now.difference(t).inDays < 7) return DateFormat.E('de').format(t);
    return DateFormat('dd.MM.yy').format(t);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.forum_outlined, size: 56, color: AppColors.stone300),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Noch keine Gespräche',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Schreibe einer Nachbarin / einem Nachbarn,\num ein Gespräch zu starten.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48, color: AppColors.emergency500),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Konnte Gespräche nicht laden',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Center(
          child: TextButton(onPressed: onRetry, child: const Text('Erneut versuchen')),
        ),
      ],
    );
  }
}
