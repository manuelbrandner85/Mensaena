import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase.dart';
import '../../navigation/nav_config.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/cards.dart';

/// Dashboard-Übersicht – Pendant zu DashboardOverview.tsx.
/// Widget-Grid mit Quick-Access auf alle Module.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final greeting = _greetingForHour(DateTime.now().hour);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Begrüßung
        AppCard(
          accent: true,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting${user != null ? ', ${user.email?.split('@').first}' : ''}!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Was möchtest du heute tun?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick-Actions
        Text(
          'Module',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final group in navGroups)
          if (!group.adminOnly) _GroupGrid(group: group),
      ],
    );
  }

  String _greetingForHour(int h) {
    if (h < 5) return 'Guten Abend';
    if (h < 11) return 'Guten Morgen';
    if (h < 18) return 'Hallo';
    return 'Guten Abend';
  }
}

class _GroupGrid extends StatelessWidget {
  const _GroupGrid({required this.group});
  final NavGroup group;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Icon(group.icon, size: 16, color: AppColors.stone500),
                const SizedBox(width: 6),
                Text(
                  group.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.stone500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              for (final item in group.items) _ModuleTile(item: item),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.item});
  final NavItem item;

  @override
  Widget build(BuildContext context) {
    final isCrisis = item.variant == NavVariant.crisis;
    return AppCard(
      onTap: () => context.go(item.path),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isCrisis ? const Color(0xFFFEE2E2) : AppColors.primary100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 20,
              color: isCrisis ? AppColors.emergency600 : AppColors.primary700,
            ),
          ),
          const Spacer(),
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
