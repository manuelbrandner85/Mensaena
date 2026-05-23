import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/push_notification_service.dart';

/// SKILL: mensaena-features
/// Listener-Widget — abonniert FirebaseMessaging.onMessage und zeigt
/// In-App-Toast wenn Push waehrend App-Foreground ankommt.
/// Behebt FCM-Foreground-Gap aus Audit Sektion 5.
class FcmForegroundListener extends StatefulWidget {
  const FcmForegroundListener({required this.child, super.key});
  final Widget child;

  @override
  State<FcmForegroundListener> createState() =>
      _FcmForegroundListenerState();
}

class _FcmForegroundListenerState extends State<FcmForegroundListener> {
  StreamSubscription<RemoteMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = PushNotificationService.onMessage.listen(_onMessage);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onMessage(RemoteMessage m) {
    if (!mounted) return;
    final notif = m.notification;
    final title = notif?.title ?? m.data['title'] as String?;
    final body = notif?.body ?? m.data['body'] as String?;
    final url = m.data['url'] as String? ?? m.data['link'] as String?;
    final type = m.data['type'] as String? ?? 'system';
    if (title == null && body == null) return;

    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    // Incoming-Call: direkt zur Chat-Screen oder Call-Screen
    if (type == 'incoming_call') {
      final callId = m.data['call_id'] as String?;
      if (callId != null && mounted) {
        context.go('/dashboard/chat?conv=$callId');
        return;
      }
    }

    final color = _colorFor(type);
    final icon = _iconFor(type);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.raised,
      duration: const Duration(seconds: 5),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('NEU',
                        style: AppTypography.label(
                            size: 8, color: color)),
                  ],
                ),
                const SizedBox(height: 2),
                if (title != null)
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                      )),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 12,
                          color: AppColors.inkSoft,
                          height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
      action: url != null
          ? SnackBarAction(
              label: 'Öffnen',
              textColor: color,
              onPressed: () => context.go(url),
            )
          : null,
    ));
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'crisis_alert':
        return AppColors.herzrot;
      case 'incoming_call':
        return AppColors.leben;
      case 'new_match':
      case 'match_partner_accepted':
      case 'match_both_accepted':
        return AppColors.tealSoft;
      case 'interaction':
      case 'help_found':
        return AppColors.lebenSoft;
      case 'message':
        return AppColors.amber;
      default:
        return AppColors.bronze;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'crisis_alert':
        return LucideIcons.alertTriangle;
      case 'incoming_call':
        return LucideIcons.phoneCall;
      case 'new_match':
      case 'match_partner_accepted':
      case 'match_both_accepted':
        return LucideIcons.sparkles;
      case 'interaction':
      case 'help_found':
        return LucideIcons.helpingHand;
      case 'message':
        return LucideIcons.messageCircle;
      case 'comment':
        return LucideIcons.messageSquare;
      case 'rating':
        return LucideIcons.star;
      default:
        return LucideIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
