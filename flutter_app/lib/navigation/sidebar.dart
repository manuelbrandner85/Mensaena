import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase.dart';
import '../theme/app_colors.dart';
import '../widgets/badges.dart';
import 'badge_counts.dart';
import 'nav_config.dart';

/// Sidebar mit gruppierter Navigation. 1:1 zu src/components/navigation/Sidebar.tsx.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final counts = ref.watch(badgeCountsProvider).asData?.value ?? const BadgeCounts();
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.appMetadata['role'] == 'admin' ||
        user?.userMetadata?['role'] == 'admin';

    return Container(
      color: AppColors.paper,
      child: Column(
        children: [
          // Brand
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary400, AppColors.primary600],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.eco, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Mensaena',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // Main items
                for (final item in mainNavItems)
                  _NavTile(
                    item: item,
                    selected: location == item.path,
                    badgeCount: counts.forKey(item.badgeKey),
                  ),
                const SizedBox(height: 8),
                // Groups
                for (final group in navGroups)
                  if (!group.adminOnly || isAdmin)
                    _NavGroupSection(
                      group: group,
                      currentLocation: location,
                      counts: counts,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavGroupSection extends StatefulWidget {
  const _NavGroupSection({
    required this.group,
    required this.currentLocation,
    required this.counts,
  });
  final NavGroup group;
  final String currentLocation;
  final BadgeCounts counts;

  @override
  State<_NavGroupSection> createState() => _NavGroupSectionState();
}

class _NavGroupSectionState extends State<_NavGroupSection> {
  late bool _expanded = widget.group.items.any((i) => widget.currentLocation.startsWith(i.path));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(widget.group.icon, size: 16, color: AppColors.stone500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.group.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.stone500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.stone400,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            for (final item in widget.group.items)
              _NavTile(
                item: item,
                selected: widget.currentLocation.startsWith(item.path),
                badgeCount: widget.counts.forKey(item.badgeKey),
                indent: true,
              ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    this.badgeCount = 0,
    this.indent = false,
  });

  final NavItem item;
  final bool selected;
  final int badgeCount;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final isCrisis = item.variant == NavVariant.crisis;
    final highlight = item.variant == NavVariant.highlight;

    final tileColor = selected
        ? (isCrisis ? const Color(0xFFFEE2E2) : AppColors.primary100)
        : Colors.transparent;
    final fg = selected
        ? (isCrisis ? AppColors.emergency600 : AppColors.primary800)
        : (isCrisis ? AppColors.emergency500 : AppColors.ink700);

    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 20 : 12, 1, 12, 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.path),
          child: Ink(
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(10),
              gradient: highlight && !selected
                  ? const LinearGradient(
                      colors: [AppColors.primary50, AppColors.warm100],
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(item.icon, size: 18, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: fg,
                      ),
                    ),
                  ),
                  if (badgeCount > 0) CountBadge(count: badgeCount),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
