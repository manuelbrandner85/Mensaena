import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/notification_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/models/notification.dart';
import 'package:mensaena/widgets/editorial_header.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final notifs = ref.watch(notificationsProvider);
    final unreadByType = ref.watch(unreadCountsByTypeProvider).valueOrNull ?? const {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Benachrichtigungen'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtern',
            onSelected: (v) => setState(() => _filter = v == 'all' ? null : v),
            itemBuilder: (_) => _filterMenuItems(unreadByType),
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Alle als gelesen markieren',
            onPressed: () async {
              final userId = ref.read(currentUserIdProvider);
              if (userId != null) {
                await ref.read(notificationServiceProvider).markAllAsRead(userId);
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationCountProvider);
                ref.invalidate(unreadCountsByTypeProvider);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Alle löschen',
            onPressed: _confirmDeleteAll,
          ),
        ],
      ),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) {
          final filtered = _filter != null ? list.where((n) => n.type == _filter).toList() : list;
          final grouped = _groupByDate(filtered);

          final header = const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: EditorialHeader(
              number: '08',
              section: 'Benachrichtigungen',
              title: 'Deine Benachrichtigungen',
              subtitle: 'Alles Wichtige aus deiner Nachbarschaft an einem Ort.',
              accentWord: 'Nachbarschaft',
              icon: Icons.notifications_none,
            ),
          );
          final preferencesLink = Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => context.push('/dashboard/settings'),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Benachrichtigungen anpassen'),
              ),
            ),
          );

          final items = <Widget>[header];
          if (grouped.isEmpty) {
            items.add(Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text('Keine Benachrichtigungen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Hier erscheinen deine Benachrichtigungen', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ));
          } else {
            for (final group in grouped) {
              if (group is String) {
                items.add(Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(group, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
                ));
              } else {
                final n = group as AppNotification;
                items.add(_NotificationTile(
                  notification: n,
                  onTap: () async {
                    if (!n.isRead) {
                      await ref.read(notificationServiceProvider).markAsRead(n.id);
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                      ref.invalidate(unreadCountsByTypeProvider);
                    }
                    if (n.link != null && n.link!.startsWith('/') && context.mounted) {
                      context.push(n.link!);
                    }
                  },
                  onDismiss: () async {
                    await ref.read(notificationServiceProvider).deleteNotification(n.id);
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadCountsByTypeProvider);
                  },
                ));
              }
            }
          }
          items.add(preferencesLink);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
              ref.invalidate(unreadCountsByTypeProvider);
            },
            color: AppColors.primary500,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items,
            ),
          );
        },
      ),
    );
  }

  List<PopupMenuEntry<String>> _filterMenuItems(Map<String, int> unread) {
    final entries = <({String value, String label})>[
      (value: 'all', label: 'Alle'),
      (value: 'message', label: 'Nachrichten'),
      (value: 'interaction', label: 'Interaktionen'),
      (value: 'comment', label: 'Kommentare'),
      (value: 'trust_rating', label: 'Bewertungen'),
      (value: 'matching', label: 'Matching'),
      (value: 'crisis', label: 'Krisen'),
      (value: 'system', label: 'System'),
    ];
    return entries.map((e) {
      final count = e.value == 'all'
          ? unread.values.fold<int>(0, (a, b) => a + b)
          : (unread[e.value] ?? 0);
      return PopupMenuItem<String>(
        value: e.value,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.label),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle Benachrichtigungen löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Alle löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(notificationServiceProvider).deleteAllNotifications(userId);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.invalidate(unreadCountsByTypeProvider);
  }

  List<dynamic> _groupByDate(List<AppNotification> notifications) {
    final result = <dynamic>[];
    String? lastGroup;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    for (final n in notifications) {
      final nDate = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      String group;
      if (nDate == today || nDate.isAfter(today)) {
        group = 'Heute';
      } else if (nDate == yesterday || (nDate.isAfter(yesterday) && nDate.isBefore(today))) {
        group = 'Gestern';
      } else if (nDate.isAfter(weekStart)) {
        group = 'Diese Woche';
      } else if (nDate.isAfter(monthStart)) {
        group = 'Dieser Monat';
      } else {
        group = 'Älter';
      }
      if (group != lastGroup) {
        result.add(group);
        lastGroup = group;
      }
      result.add(n);
    }
    return result;
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  const _NotificationTile({required this.notification, required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final color = _getColor(notification.type);
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withValues(alpha: 0.1),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onDismiss(),
      child: Material(
        color: notification.isRead ? Colors.transparent : AppColors.primary50.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getIcon(notification.type), color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            timeago.format(notification.createdAt, locale: 'de'),
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                      ),
                      if (notification.isHighPriority)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emergency.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Wichtig', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.emergency)),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 8, top: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary500,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'message': return Icons.chat_bubble_outline;
      case 'interaction': return Icons.handshake_outlined;
      case 'trust_rating': return Icons.shield_outlined;
      case 'post_nearby': return Icons.location_on_outlined;
      case 'post_response': return Icons.reply_outlined;
      case 'crisis': return Icons.warning_outlined;
      case 'comment': return Icons.comment_outlined;
      case 'event': return Icons.event_outlined;
      case 'matching': return Icons.auto_awesome;
      case 'zeitbank_confirmation': return Icons.access_time;
      case 'welcome': return Icons.waving_hand;
      case 'badge': return Icons.military_tech;
      case 'mention': return Icons.alternate_email;
      case 'reminder': return Icons.alarm;
      case 'bot': return Icons.smart_toy_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'crisis': return AppColors.emergency;
      case 'message': return AppColors.info;
      case 'interaction': return AppColors.primary500;
      case 'trust_rating': return AppColors.trust;
      case 'matching': return AppColors.warning;
      case 'comment': return const Color(0xFF8B5CF6);
      case 'event': return const Color(0xFF10B981);
      case 'badge': return const Color(0xFFF59E0B);
      case 'welcome': return AppColors.primary500;
      default: return AppColors.textMuted;
    }
  }
}
