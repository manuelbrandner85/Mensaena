import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/notification_model.dart';
import '../../repositories/notifications_repository.dart';
import '../../services/notification_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Notifications-Screen mit Realtime-Stream + Kategorie-Tabs.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const List<({String key, String label})> _tabs = [
    (key: 'all', label: 'Alle'),
    (key: 'unread', label: 'Ungelesen'),
    (key: 'message', label: 'Nachrichten'),
    (key: 'interaction', label: 'Interaktionen'),
    (key: 'system', label: 'System'),
  ];

  String _tab = 'all';

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(notificationsStreamProvider);
    return DashboardScaffold(
      title: 'Benachrichtigungen',
      currentRoute: '/dashboard/notifications',
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final t = _tabs[i];
                  final active = t.key == _tab;
                  return GestureDetector(
                    onTap: () => setState(() => _tab = t.key),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.amber.withValues(alpha: 0.18)
                            : AppColors.surface.withValues(alpha: 0.5),
                        border: Border.all(
                          color: active ? AppColors.amber : AppColors.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t.label,
                        style: AppTypography.label(
                          size: 10,
                          color: active ? AppColors.amber : AppColors.inkSoft,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: stream.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Fehler: $e',
                    style: AppTypography.caption(),
                  ),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.bellOff,
                            size: 32,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keine Benachrichtigungen.',
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) =>
                        _NotificationTile(notif: filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppNotification> _filter(List<AppNotification> all) {
    switch (_tab) {
      case 'unread':
        return all.where((n) => !n.read && n.readAt == null).toList();
      case 'message':
        return all.where((n) => n.category == 'message').toList();
      case 'interaction':
        return all
            .where((n) =>
                n.category == 'interaction' || n.category == 'post_response')
            .toList();
      case 'system':
        return all.where((n) {
          return n.category == 'system' ||
              n.category == 'bot' ||
              n.category == 'welcome';
        }).toList();
      default:
        return all;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notif});
  final AppNotification notif;

  @override
  Widget build(BuildContext context) {
    final style = NotificationService.styleFor(notif.category ?? notif.type);
    final unread = !notif.read && notif.readAt == null;
    return InkWell(
      onTap: () async {
        await NotificationsRepository.markRead(notif.id);
        if (!context.mounted) return;
        if (notif.link != null && notif.link!.isNotEmpty) {
          context.go(notif.link!);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread
              ? style.color.withValues(alpha: 0.08)
              : AppColors.surface.withValues(alpha: 0.4),
          border: Border.all(
            color: unread ? style.color.withValues(alpha: 0.4) : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(style.icon, size: 16, color: style.color),
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
                          notif.title,
                          style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        NotificationService.relativeTime(notif.createdAt),
                        style: AppTypography.body(
                          size: 11,
                          color: AppColors.mute,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.inkSoft,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              const Padding(
                padding: EdgeInsets.only(left: 6, top: 4),
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: AppColors.amber,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
