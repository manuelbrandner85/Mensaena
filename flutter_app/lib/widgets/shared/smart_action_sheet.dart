/// SKILL: mensaena-features + mensaena-design
/// Smart-Action-Sheet — ersetzt den generischen CreatePostScreen.
///
/// Öffnet ein elegant gestaltetes Bottom-Sheet mit den 8 häufigsten
/// User-Aktionen. Jede Aktion navigiert direkt zum kontext-spezifischen
/// Create-Flow des jeweiligen Moduls.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class SmartActionSheet {
  const SmartActionSheet._();

  static Future<void> show(BuildContext context) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ActionSheetContent(),
    );
  }
}

class _ActionSheetContent extends StatelessWidget {
  const _ActionSheetContent();

  static const _actions = <_Action>[
    _Action(
      icon: LucideIcons.helpingHand,
      label: 'Hilfe anbieten',
      sub: 'Was kannst du tun?',
      color: AppColors.leben,
      route: '/dashboard/create?type=help_offer',
    ),
    _Action(
      icon: LucideIcons.heartHandshake,
      label: 'Hilfe suchen',
      sub: 'Was brauchst du?',
      color: AppColors.amber,
      route: '/dashboard/create?type=help_request',
    ),
    _Action(
      icon: LucideIcons.calendar,
      label: 'Event posten',
      sub: 'Veranstaltung organisieren',
      color: AppColors.bronze,
      route: '/dashboard/events/create',
    ),
    _Action(
      icon: LucideIcons.store,
      label: 'Marktplatz',
      sub: 'Verschenken/verkaufen',
      color: AppColors.bronze,
      route: '/dashboard/marketplace/create',
    ),
    _Action(
      icon: LucideIcons.bookOpen,
      label: 'Wissen teilen',
      sub: 'Artikel schreiben',
      color: AppColors.tealSoft,
      route: '/dashboard/knowledge/create',
    ),
    _Action(
      icon: LucideIcons.stickyNote,
      label: 'Pinnwand',
      sub: 'Schnelle Notiz',
      color: AppColors.tealSoft,
      route: '/dashboard/board/create',
    ),
    _Action(
      icon: LucideIcons.users2,
      label: 'Gruppe gründen',
      sub: 'Nachbarschaft-Initiative',
      color: AppColors.lebenSoft,
      route: '/dashboard/groups/create',
    ),
    _Action(
      icon: LucideIcons.alertTriangle,
      label: 'Krise melden',
      sub: 'Notfall in der Nähe',
      color: AppColors.herzrot,
      route: '/dashboard/crisis/create',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag-Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Was möchtest du tun?',
              textAlign: TextAlign.center,
              style: AppTypography.display(size: 20, color: AppColors.ink),
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
              ),
              itemCount: _actions.length,
              itemBuilder: (_, i) => _ActionTile(
                action: _actions[i],
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  context.go(_actions[i].route);
                },
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr(),
                  style: AppTypography.body(
                      size: 13, color: AppColors.mute)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final String route;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.onTap});
  final _Action action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              action.color.withValues(alpha: 0.22),
              action.color.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: action.color.withValues(alpha: 0.45), width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, size: 18, color: action.color),
            ),
            const SizedBox(height: 6),
            Text(action.label,
                style: AppTypography.body(
                    size: 13,
                    color: AppColors.ink,
                    weight: FontWeight.w700)),
            Text(action.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(size: 9, color: AppColors.mute)),
          ],
        ),
      ),
    );
  }
}
