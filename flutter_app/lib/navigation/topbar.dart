import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase.dart';
import '../routing/routes.dart';
import '../theme/app_colors.dart';
import '../widgets/badges.dart';
import 'badge_counts.dart';

/// Topbar – Pendant zu src/components/navigation/Topbar.tsx.
class Topbar extends ConsumerWidget implements PreferredSizeWidget {
  const Topbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(badgeCountsProvider).asData?.value ?? const BadgeCounts();
    final isMobile = MediaQuery.sizeOf(context).width < 1024;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(bottom: BorderSide(color: AppColors.stone200)),
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.ink700),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          if (isMobile)
            Text('Mensaena', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.ink600),
            onPressed: () => context.push(Routes.search),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.ink600),
                onPressed: () => context.go(Routes.dashboardNotifications),
              ),
              if (counts.unreadNotifications > 0)
                Positioned(top: 6, right: 4, child: CountBadge(count: counts.unreadNotifications)),
            ],
          ),
          PopupMenuButton<String>(
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary100,
              child: Icon(Icons.person, size: 18, color: AppColors.primary700),
            ),
            onSelected: (v) async {
              if (v == 'profile') context.go(Routes.dashboardProfile);
              if (v == 'settings') context.go(Routes.dashboardSettings);
              if (v == 'logout') {
                await sb.auth.signOut();
                if (context.mounted) context.go(Routes.auth);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('Mein Profil')),
              PopupMenuItem(value: 'settings', child: Text('Einstellungen')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Abmelden')),
            ],
          ),
        ],
      ),
    );
  }
}
