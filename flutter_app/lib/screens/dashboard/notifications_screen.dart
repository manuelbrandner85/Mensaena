import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../widgets/shared/error_state_widget.dart';
import '../../models/notification_model.dart';
import '../../services/notification_router.dart';
import '../../repositories/notifications_repository.dart';
import '../../services/notification_service.dart';
import '../../widgets/effects/animated_entrance.dart';
import '../../widgets/effects/shimmer_skeleton.dart';
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
    (key: 'mention', label: 'Erwähnungen'),
    (key: 'interaction', label: 'Interaktionen'),
    (key: 'system', label: 'System'),
  ];

  String _tab = 'all';
  static const _tabPrefKey = 'mensaena_notif_tab_v1';
  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadTabPref();
  }

  Future<void> _loadTabPref() async {
    try {
      final raw = await _storage.read(key: _tabPrefKey);
      if (raw != null && _tabs.any((t) => t.key == raw) && mounted) {
        setState(() => _tab = raw);
      }
    } catch (_) {}
  }

  Future<void> _setTab(String t) async {
    setState(() => _tab = t);
    try {
      await _storage.write(key: _tabPrefKey, value: t);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(notificationsStreamProvider);
    final unread = stream.value
            ?.where((n) => !n.read && n.readAt == null)
            .length ??
        0;
    return DashboardScaffold(
      title: 'notifications.screenTitle'.tr(),
      currentRoute: '/dashboard/notifications',
      body: SafeArea(
        child: Column(
          children: [
            // Editorial-Header entfernt: die Unread-Zahl steht bereits in der
            // Action-Bar darunter (Redundanz) — spart Platz, mehr Liste sichtbar.
            // ── Action-Bar: Mark-All-Read ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  if (unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('$unread ungelesen',
                          style: AppTypography.label(
                              size: 10, color: AppColors.amber)),
                    )
                  else
                    Text('notifications.allRead'.tr(),
                        style: AppTypography.caption()),
                  const Spacer(),
                  if (unread > 0)
                    TextButton.icon(
                      onPressed: () async {
                        await NotificationsRepository.markAllRead();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.surface,
                            content: Text(
                              'Alles als gelesen markiert.',
                              style: AppTypography.body(
                                  size: 13, color: AppColors.ink),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.checkCheck,
                          size: 14, color: AppColors.amber),
                      label: Text('notifications.markAllRead'.tr(),
                          style: AppTypography.label(
                              size: 10, color: AppColors.amber)),
                    ),
                  IconButton(
                    tooltip: 'notifications.tooltipClearAll'.tr(),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          title: Text('notifications.deleteAllTitle'.tr(),
                              style: AppTypography.body(
                                  size: 15,
                                  color: AppColors.ink,
                                  weight: FontWeight.w700)),
                          content: Text(
                            'Alle Benachrichtigungen werden entfernt. Das kann nicht rückgängig gemacht werden.',
                            style: AppTypography.body(
                                size: 13, color: AppColors.inkSoft),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('common.cancel'.tr()),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: AppColors.herzrot),
                              child: Text('common.delete'.tr()),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                      final ok = await NotificationsRepository.deleteAll();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text(
                            ok
                                ? 'Alle Benachrichtigungen gelöscht.'
                                : 'Löschen fehlgeschlagen.',
                            style: AppTypography.body(
                                size: 13, color: AppColors.ink),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.trash2,
                        size: 14, color: AppColors.mute),
                  ),
                ],
              ),
            ),
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
                    onTap: () => _setTab(t.key),
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
                loading: () => ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  itemCount: 6,
                  itemBuilder: (_, __) => const NotificationTileSkeleton(),
                ),
                error: (e, _) => Center(
                  child: ErrorStateWidget(
                    onRetry: () =>
                        ref.invalidate(notificationsStreamProvider),
                  ),
                ),
                data: (all) {
                  final filtered = _filter(all);
                  if (filtered.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.amber,
                      backgroundColor: AppColors.surface,
                      onRefresh: () async {
                        ref.invalidate(notificationsStreamProvider);
                        await Future<void>.delayed(
                            const Duration(milliseconds: 400));
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 120),
                          const Icon(
                            LucideIcons.bellOff,
                            size: 32,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keine Benachrichtigungen.',
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.amber,
                    backgroundColor: AppColors.surface,
                    onRefresh: () async {
                      ref.invalidate(notificationsStreamProvider);
                      await Future<void>.delayed(
                          const Duration(milliseconds: 400));
                    },
                    child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final n = filtered[i];
                      return AnimatedEntrance(
                        index: i,
                        child: Dismissible(
                        key: ValueKey('notif_${n.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: AppColors.herzrot.withValues(alpha: 0.25),
                            border: Border.all(
                                color: AppColors.herzrot
                                    .withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(LucideIcons.trash2,
                              color: AppColors.herzrotWarm, size: 20),
                        ),
                        onDismissed: (_) async {
                          await NotificationsRepository.delete(n.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.surface,
                              duration: const Duration(seconds: 2),
                              content: Text(
                                'Benachrichtigung gelöscht.',
                                style: AppTypography.body(
                                    size: 13, color: AppColors.ink),
                              ),
                            ),
                          );
                        },
                        child: _NotificationTile(notif: n),
                      ),
                      );
                    },
                    ),
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
    final filtered = switch (_tab) {
      'unread' => all.where((n) => !n.read && n.readAt == null).toList(),
      'message' => all.where((n) => n.category == 'message').toList(),
      'interaction' => all
          .where((n) =>
              n.category == 'interaction' || n.category == 'post_response')
          .toList(),
      'system' => all.where((n) {
          return n.category == 'system' ||
              n.category == 'bot' ||
              n.category == 'welcome';
        }).toList(),
      _ => List<AppNotification>.from(all),
    };
    return _groupSimilar(filtered);
  }

  /// F22: Aggregiert Notifications mit gleichem `type` + gleichem
  /// `target_id` (aus metadata) wenn sie innerhalb 1h liegen. Behält die
  /// neueste Notification und hängt im Titel "und X weitere" an. Lese-
  /// status, Tap-Routing usw. nehmen die neueste Notification als Basis.
  List<AppNotification> _groupSimilar(List<AppNotification> input) {
    final groups = <String, List<AppNotification>>{};
    final order = <String>[];
    for (final n in input) {
      final target = (n.metadata['post_id']
              ?? n.metadata['conversation_id']
              ?? n.metadata['event_id']
              ?? n.metadata['crisis_id']
              ?? n.metadata['friendship_id']
              ?? '').toString();
      // Buckets bei leerem target keinen Group-Key — bleibt einzeln.
      if (target.isEmpty) {
        final k = 'solo_${n.id}';
        groups[k] = [n];
        order.add(k);
        continue;
      }
      final bucketHour = n.createdAt
          .toUtc()
          .toIso8601String()
          .substring(0, 13); // YYYY-MM-DDTHH
      final key = '${n.type}_${target}_$bucketHour';
      groups.putIfAbsent(key, () {
        order.add(key);
        return <AppNotification>[];
      }).add(n);
    }
    final out = <AppNotification>[];
    for (final k in order) {
      final g = groups[k]!;
      if (g.length <= 1) {
        out.add(g.first);
        continue;
      }
      final newest = g.first;
      final extra = g.length - 1;
      out.add(newest.copyWith(
        title: '${newest.title} · +$extra',
      ));
    }
    return out;
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
        // F23: Smart-Routing — nutzt zentrale Router-Logik. Fallback auf
        // link-Feld nur wenn Router-Map keinen Treffer hat.
        NotificationRouter.navigate(GoRouter.of(context), notif);
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
