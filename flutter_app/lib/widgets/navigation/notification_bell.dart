import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/notifications_repository.dart';

/// SKILL: mensaena-design
/// Bell-Icon mit Unread-Badge im AppBar. Tippen oeffnet /notifications.
///
/// PERF (Audit): Vorher watchte das umschließende DashboardScaffold den
/// unreadNotificationCountProvider direkt → bei jedem Notification-Stream-
/// Event wurde das KOMPLETTE Scaffold (inkl. Body) neu gebaut. Jetzt
/// watcht NotificationBell selbst → rebuild beschränkt sich auf den Bell-
/// Subtree, der Scaffold-Body bleibt stabil.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    return InkWell(
      onTap: () => context.go('/dashboard/notifications'),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              LucideIcons.bell,
              size: 22,
              color: AppColors.ink,
            ),
            if (unreadCount > 0)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.herzrot,
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      size: 10,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
