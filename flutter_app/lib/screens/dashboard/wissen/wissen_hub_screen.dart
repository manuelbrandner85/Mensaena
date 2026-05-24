/// SKILL: mensaena-features + mensaena-design
/// Wissen-Hub — Launcher-Screen für die 3 Wissens-Module.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class WissenHubScreen extends ConsumerWidget {
  const WissenHubScreen({super.key});

  static const _tiles = <_HubTile>[
    _HubTile(
      icon: LucideIcons.bookOpen,
      title: 'Wiki',
      sub: 'Gemeinsames Lexikon, Anleitungen, FAQ',
      color: AppColors.bronze,
      route: '/dashboard/wiki',
    ),
    _HubTile(
      icon: LucideIcons.graduationCap,
      title: 'Bildung',
      sub: 'Kurse, Workshops, Lernmaterial',
      color: AppColors.amber,
      route: '/dashboard/knowledge',
    ),
    _HubTile(
      icon: LucideIcons.wrench,
      title: 'Skills',
      sub: 'Wer kann was — Personen mit ihren Fähigkeiten',
      color: AppColors.tealSoft,
      route: '/dashboard/skills',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashboardScaffold(
      title: 'Wissen',
      currentRoute: '/dashboard/wissen',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text('Wissen teilen',
                style: AppTypography.display(
                    size: 26, color: AppColors.ink, height: 1.15)),
            const SizedBox(height: 4),
            Text(
              'Drei Bereiche, in denen die Nachbarschaft Wissen verfügbar macht — vom kleinen Tipp bis zum ganzen Kurs.',
              style: AppTypography.body(
                  size: 13, color: AppColors.mute, height: 1.5),
            ),
            const SizedBox(height: 22),
            for (final t in _tiles)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LauncherTile(tile: t),
              ),
          ],
        ),
      ),
    );
  }
}

class _HubTile {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final String route;
}

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({required this.tile});
  final _HubTile tile;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(tile.route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tile.color.withValues(alpha: 0.22),
              tile.color.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: tile.color.withValues(alpha: 0.45), width: 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: tile.color.withValues(alpha: 0.20),
              blurRadius: 14,
              spreadRadius: -3,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tile.color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: tile.color.withValues(alpha: 0.5)),
              ),
              child: Icon(tile.icon, size: 26, color: tile.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tile.title.tr(),
                      style: AppTypography.body(
                          size: 16,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(tile.sub,
                      style: AppTypography.body(
                          size: 12,
                          color: AppColors.inkSoft,
                          height: 1.4)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 16,
                color: tile.color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
