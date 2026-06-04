/// SKILL: mensaena-features (UX-Welle1 N1)
/// Modules-Hub — eine Übersichts-Seite mit Karten-Grid aller Module.
/// Statt nur via Drawer zugänglich. Tap auf Karte pusht zum Modul.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/haptics.dart';
import '../../widgets/effects/tilt_card.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

class ModuleTile {
  const ModuleTile({
    required this.label,
    required this.route,
    required this.icon,
    required this.tint,
    required this.section,
  });
  final String label;
  final String route;
  final IconData icon;
  final Color tint;
  final String section;
}

const kModulesCatalog = <ModuleTile>[
  // Helfen & Finden
  ModuleTile(
      label: 'nav.map',
      route: '/dashboard/map',
      icon: LucideIcons.map,
      tint: Color(0xFF66C7C8),
      section: 'navGroups.helpAndFind'),
  ModuleTile(
      label: 'nav.posts',
      route: '/dashboard/posts',
      icon: LucideIcons.fileText,
      tint: Color(0xFFC79363),
      section: 'navGroups.helpAndFind'),
  ModuleTile(
      label: 'nav.organizations',
      route: '/dashboard/organizations',
      icon: LucideIcons.building2,
      tint: Color(0xFFB48455),
      section: 'navGroups.helpAndFind'),
  ModuleTile(
      label: 'nav.interactions',
      route: '/dashboard/interactions',
      icon: LucideIcons.helpingHand,
      tint: Color(0xFFE8A24A),
      section: 'navGroups.helpAndFind'),
  ModuleTile(
      label: 'nav.animals',
      route: '/dashboard/animals',
      icon: LucideIcons.dog,
      tint: Color(0xFF7BD389),
      section: 'navGroups.helpAndFind'),
  // Notfall & Sicherheit
  ModuleTile(
      label: 'nav.crisis',
      route: '/dashboard/crisis',
      icon: LucideIcons.alertTriangle,
      tint: Color(0xFFE26B6B),
      section: 'navGroups.emergencyAndSafety'),
  ModuleTile(
      label: 'nav.mentalSupport',
      route: '/dashboard/mental-support',
      icon: LucideIcons.brain,
      tint: Color(0xFFC084FC),
      section: 'navGroups.emergencyAndSafety'),
  // Gemeinschaft
  ModuleTile(
      label: 'nav.groups',
      route: '/dashboard/groups',
      icon: LucideIcons.users2,
      tint: Color(0xFFC79363),
      section: 'navGroups.community'),
  ModuleTile(
      label: 'nav.events',
      route: '/dashboard/events',
      icon: LucideIcons.calendar,
      tint: Color(0xFFF59E0B),
      section: 'navGroups.community'),
  ModuleTile(
      label: 'nav.board',
      route: '/dashboard/board',
      icon: LucideIcons.stickyNote,
      tint: Color(0xFFE8A24A),
      section: 'navGroups.community'),
  ModuleTile(
      label: 'nav.challenges',
      route: '/dashboard/challenges',
      icon: LucideIcons.trophy,
      tint: Color(0xFFF59E0B),
      section: 'navGroups.community'),
  // Teilen & Ressourcen
  ModuleTile(
      label: 'nav.marketplace',
      route: '/dashboard/marketplace',
      icon: LucideIcons.shoppingBag,
      tint: Color(0xFFC79363),
      section: 'navGroups.shareAndResources'),
  ModuleTile(
      label: 'nav.supply',
      route: '/dashboard/supply',
      icon: LucideIcons.package,
      tint: Color(0xFFE8A24A),
      section: 'navGroups.shareAndResources'),
  ModuleTile(
      label: 'nav.harvest',
      route: '/dashboard/harvest',
      icon: LucideIcons.wheat,
      tint: Color(0xFF7BD389),
      section: 'navGroups.shareAndResources'),
  ModuleTile(
      label: 'nav.rescuer',
      route: '/dashboard/rescuer',
      icon: LucideIcons.lifeBuoy,
      tint: Color(0xFFE26B6B),
      section: 'navGroups.shareAndResources'),
  ModuleTile(
      label: 'nav.housing',
      route: '/dashboard/housing',
      icon: LucideIcons.home,
      tint: Color(0xFF66C7C8),
      section: 'navGroups.shareAndResources'),
  ModuleTile(
      label: 'nav.mobility',
      route: '/dashboard/mobility',
      icon: LucideIcons.car,
      tint: Color(0xFF66C7C8),
      section: 'navGroups.shareAndResources'),
  ModuleTile(
      label: 'nav.jobs',
      route: '/dashboard/jobs',
      icon: LucideIcons.briefcase,
      tint: Color(0xFFB48455),
      section: 'navGroups.shareAndResources'),
  ModuleTile(
      label: 'nav.timebank',
      route: '/dashboard/timebank',
      icon: LucideIcons.timer,
      tint: Color(0xFFC79363),
      section: 'navGroups.shareAndResources'),
  // Wissen & Skills
  ModuleTile(
      label: 'nav.wiki',
      route: '/dashboard/wiki',
      icon: LucideIcons.bookOpen,
      tint: Color(0xFFB48455),
      section: 'navGroups.knowledgeAndSkills'),
  ModuleTile(
      label: 'nav.knowledge',
      route: '/dashboard/knowledge',
      icon: LucideIcons.graduationCap,
      tint: Color(0xFFE8A24A),
      section: 'navGroups.knowledgeAndSkills'),
  ModuleTile(
      label: 'nav.skills',
      route: '/dashboard/skills',
      icon: LucideIcons.wrench,
      tint: Color(0xFFC79363),
      section: 'navGroups.knowledgeAndSkills'),
];

class ModulesHubScreen extends ConsumerWidget {
  const ModulesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bySection = <String, List<ModuleTile>>{};
    for (final m in kModulesCatalog) {
      bySection.putIfAbsent(m.section, () => []).add(m);
    }
    return DashboardScaffold(
      title: 'modulesHub.title'.tr(),
      currentRoute: '/dashboard/modules',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'modulesHub.intro'.tr(),
                style: AppTypography.body(
                    size: 13, color: AppColors.inkSoft, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            for (final sectionKey in bySection.keys) ...[
              // Editorial-Header (konsistent mit dem Dashboard): Versal-Label
              // + auslaufende Bronze-Haarlinie statt schlichtem Grau-Text.
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
                child: Row(
                  children: [
                    Text(
                      sectionKey.tr().toUpperCase(),
                      style: AppTypography.label(
                          size: 10,
                          color: AppColors.inkSoft,
                          letterSpacing: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.bronze.withValues(alpha: 0.28),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 170,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.05,
                ),
                itemCount: bySection[sectionKey]!.length,
                itemBuilder: (_, i) {
                  final m = bySection[sectionKey]![i];
                  return _ModuleCard(tile: m);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.tile});
  final ModuleTile tile;

  @override
  Widget build(BuildContext context) {
    return TiltCard(
      intensity: 0.5,
      borderRadius: 16,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Haptics.tap();
          context.push(tile.route);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tile.tint.withValues(alpha: 0.16),
                AppColors.surface.withValues(alpha: 0.45),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: tile.tint.withValues(alpha: 0.32)),
            borderRadius: BorderRadius.circular(16),
            // Premium-Tiefe: weicher, breiter Schatten + dezenter Farb-Glow
            // statt der harten 2px-Kante zuvor.
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 16,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: tile.tint.withValues(alpha: 0.10),
                blurRadius: 18,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    tile.tint.withValues(alpha: 0.42),
                    tile.tint.withValues(alpha: 0.10),
                  ]),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: tile.tint.withValues(alpha: 0.55)),
                  boxShadow: [
                    BoxShadow(
                      color: tile.tint.withValues(alpha: 0.28),
                      blurRadius: 14,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Icon(tile.icon, color: tile.tint, size: 22),
              ),
              const SizedBox(height: 9),
              Text(
                tile.label.tr(),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                    size: 12,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                    height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
