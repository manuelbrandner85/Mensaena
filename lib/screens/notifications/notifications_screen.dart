import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/notification_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _filter;

  @override Widget build(BuildContext context) {
    final notifs = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Benachrichtigungen'), actions: [
        PopupMenuButton<String>(icon: const Icon(Icons.filter_list), onSelected: (v) => setState(() => _filter = v == 'all' ? null : v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'all', child: Text('Alle')),
            const PopupMenuItem(value: 'message', child: Text('Nachrichten')),
            const PopupMenuItem(value: 'interaction', child: Text('Interaktionen')),
            const PopupMenuItem(value: 'system', child: Text('System')),
          ]),
        IconButton(icon: const Icon(Icons.done_all), onPressed: () async {
          final userId = ref.read(currentUserIdProvider);
          if (userId != null) { await ref.read(notificationServiceProvider).markAllAsRead(userId); ref.invalidate(notificationsProvider); }
        }),
      ]),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) {
          final filtered = _filter != null ? list.where((n) => n.type == _filter).toList() : list;
          if (filtered.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.notifications_none, size: 56, color: AppColors.textMuted), SizedBox(height: 12), Text('Keine Benachrichtigungen')]));
          return RefreshIndicator(onRefresh: () async { ref.invalidate(notificationsProvider); },
            child: ListView.separated(itemCount: filtered.length, separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = filtered[i];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: n.isRead ? AppColors.borderLight : AppColors.primary50,
                    child: Icon(_getIcon(n.type), color: n.isRead ? AppColors.textMuted : AppColors.primary500, size: 20)),
                  title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600, fontSize: 14)),
                  subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  trailing: Text(timeago.format(n.createdAt, locale: 'de'), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  onTap: () async { await ref.read(notificationServiceProvider).markAsRead(n.id); ref.invalidate(notificationsProvider); },
                );
              }));
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'message': return Icons.chat_bubble_outline;
      case 'interaction': return Icons.handshake_outlined;
      case 'trust_rating': return Icons.shield_outlined;
      case 'post_nearby': return Icons.location_on_outlined;
      case 'crisis': return Icons.warning_outlined;
      default: return Icons.notifications_outlined;
    }
  }
}