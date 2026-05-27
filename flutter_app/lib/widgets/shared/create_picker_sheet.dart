/// SKILL: mensaena-features (UX-Welle1 C1)
/// Universeller Create-Picker — Bottom-Sheet mit 6 Optionen.
/// Cinema-Hyperreal: GlassCard, Bronze-Icons, Tile-Layout.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class CreatePickerSheet {
  const CreatePickerSheet._();

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(LucideIcons.plus,
                    size: 18, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text('create.picker_title'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
              ]),
              const SizedBox(height: 4),
              Text('create.picker_subtitle'.tr(),
                  style: AppTypography.caption()),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  // v2.1: 'Neuer Beitrag' raus — Beiträge werden über
                  // das jeweilige Modul (Plus-Button im Module-Screen)
                  // erstellt, nicht zentral.
                  _Tile(
                    icon: LucideIcons.calendar,
                    label: 'create.picker.event'.tr(),
                    desc: 'create.picker.event_desc'.tr(),
                    color: AppColors.amber,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push('/dashboard/events/create');
                    },
                  ),
                  _Tile(
                    icon: LucideIcons.shoppingBag,
                    label: 'create.picker.marketplace'.tr(),
                    desc: 'create.picker.marketplace_desc'.tr(),
                    color: AppColors.tealSoft,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push('/dashboard/marketplace/create');
                    },
                  ),
                  _Tile(
                    icon: LucideIcons.users,
                    label: 'create.picker.group'.tr(),
                    desc: 'create.picker.group_desc'.tr(),
                    color: AppColors.bronze,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push('/dashboard/groups/create');
                    },
                  ),
                  _Tile(
                    icon: LucideIcons.bookOpen,
                    label: 'create.picker.knowledge'.tr(),
                    desc: 'create.picker.knowledge_desc'.tr(),
                    color: AppColors.amber,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push('/dashboard/wiki/create');
                    },
                  ),
                  _Tile(
                    icon: LucideIcons.shieldAlert,
                    label: 'create.picker.crisis'.tr(),
                    desc: 'create.picker.crisis_desc'.tr(),
                    color: AppColors.herzrotWarm,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      context.push('/dashboard/crisis/create');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.desc,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const Spacer(),
            Text(label,
                style: AppTypography.body(
                    size: 14,
                    color: AppColors.ink,
                    weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                    size: 11, color: AppColors.inkSoft, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
