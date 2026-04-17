import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/models/notification.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';

void showRichNotificationSnackbar(
  BuildContext context,
  WidgetRef ref,
  AppNotification notification,
) {
  final location = GoRouterState.of(context).matchedLocation;
  if (location == '/dashboard/notifications') return;

  final color = _getNotifColor(notification.type);

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notification.actorId != null)
          FutureBuilder(
            future: ref.read(supabaseProvider).from('profiles').select('name, avatar_url').eq('id', notification.actorId!).maybeSingle(),
            builder: (_, snap) {
              final profile = snap.data;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AvatarWidget(
                  imageUrl: profile?['avatar_url'] as String?,
                  name: profile?['name'] as String? ?? '?',
                  size: 36,
                ),
              );
            },
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getNotifIcon(notification.type), size: 18, color: color),
            ),
          ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                notification.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
              ),
              const SizedBox(height: 4),
              Text(
                timeago.format(notification.createdAt, locale: 'de'),
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    backgroundColor: const Color(0xFF1F2937),
    duration: const Duration(seconds: 6),
    dismissDirection: DismissDirection.down,
    action: notification.link != null
        ? SnackBarAction(
            label: 'Anzeigen',
            textColor: AppColors.primary200,
            onPressed: () {
              if (notification.link!.startsWith('/')) {
                context.push(notification.link!);
              }
            },
          )
        : null,
  ));
}

IconData _getNotifIcon(String type) {
  switch (type) {
    case 'message': return Icons.chat_bubble_outline;
    case 'interaction': return Icons.handshake_outlined;
    case 'trust_rating': return Icons.shield_outlined;
    case 'post_nearby': return Icons.location_on_outlined;
    case 'crisis': return Icons.warning_outlined;
    case 'comment': return Icons.comment_outlined;
    case 'event': return Icons.event_outlined;
    case 'matching': return Icons.auto_awesome;
    case 'zeitbank_confirmation': return Icons.access_time;
    case 'welcome': return Icons.waving_hand;
    case 'badge': return Icons.military_tech;
    default: return Icons.notifications_outlined;
  }
}

Color _getNotifColor(String type) {
  switch (type) {
    case 'crisis': return AppColors.emergency;
    case 'message': return AppColors.info;
    case 'interaction': return AppColors.primary500;
    case 'trust_rating': return AppColors.trust;
    case 'matching': return AppColors.warning;
    default: return AppColors.primary500;
  }
}
