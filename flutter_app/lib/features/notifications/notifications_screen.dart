import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_avatar.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase/database_service.dart';

final notificationsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, bool>((ref, unreadOnly) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return db.listNotifications(user.id, unreadOnly: unreadOnly);
});

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationsProvider(_unreadOnly));
    final user = ref.watch(currentUserProvider);

    return CinemaScaffold(
      appBar: CinemaAppBar(
        title: 'BENACHRICHTIGUNGEN',
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GlowButton(
                label: 'Alle gelesen',
                variant: GlowVariant.ghost,
                compact: true,
                onPressed: () async {
                  await db.markAllRead(user.id);
                  ref.invalidate(notificationsProvider);
                },
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Alle'),
                    selected: !_unreadOnly,
                    onSelected: (_) => setState(() => _unreadOnly = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Ungelesen'),
                    selected: _unreadOnly,
                    onSelected: (_) => setState(() => _unreadOnly = true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.when(
                loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
                error: (e, _) => CinemaEmptyState(
                  icon: LucideIcons.alertCircle,
                  title: 'Fehler',
                  message: e.toString(),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const CinemaEmptyState(
                      icon: LucideIcons.bell,
                      title: 'Keine Benachrichtigungen.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _NotificationTile(notification: items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _NotificationTile({required this.notification});

  IconData get _icon {
    switch (notification['type'] as String?) {
      case 'neue_nachricht':
        return LucideIcons.messageCircle;
      case 'post_geliked':
        return LucideIcons.heart;
      case 'neuer_kommentar':
        return LucideIcons.messageSquare;
      case 'trust_bewertung':
        return LucideIcons.star;
      case 'krise_aktiviert':
        return LucideIcons.alertTriangle;
      case 'badge_erhalten':
        return LucideIcons.award;
      default:
        return LucideIcons.bell;
    }
  }

  Color get _color {
    switch (notification['type'] as String?) {
      case 'krise_aktiviert':
        return MnColors.herzrot;
      case 'post_geliked':
        return MnColors.herzrotWarm;
      case 'trust_bewertung':
      case 'badge_erhalten':
        return MnColors.trust;
      case 'neue_nachricht':
      case 'neuer_kommentar':
        return MnColors.teal;
      default:
        return MnColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final read = notification['read'] == true;
    final target = notification['target_url'] as String?;
    return InkWell(
      onTap: target == null ? null : () => GoRouter.of(context).push(target),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MnColors.elevated,
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          border: Border(
            left: BorderSide(
              color: read ? MnColors.line : MnColors.amber,
              width: read ? 1 : 2,
            ),
          ),
        ),
        child: Row(
          children: [
            const CinemaAvatar(size: AvatarSize.sm),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (notification['title'] as String?) ?? '',
                    style: MnTypography.body(weight: FontWeight.w600),
                  ),
                  Text(
                    (notification['body'] as String?) ?? '',
                    style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                  ),
                ],
              ),
            ),
            Icon(_icon, size: 20, color: _color),
          ],
        ),
      ),
    );
  }
}
