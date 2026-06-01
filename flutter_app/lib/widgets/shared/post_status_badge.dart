/// SKILL: mensaena-design
/// PostStatusBadge — kleines Lifecycle-Badge (#P6). Zeigt den Status eines
/// Posts: Offen / In Bearbeitung / Erledigt. "active" rendert nichts
/// (Default-Zustand braucht kein Badge), nur abweichende Status.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class PostStatusBadge extends StatelessWidget {
  const PostStatusBadge({required this.status, this.compact = false, super.key});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, Color color, String i18n})? spec = switch (status) {
      'in_progress' => (
          icon: LucideIcons.loader,
          color: AppColors.amber,
          i18n: 'posts.statusInProgress',
        ),
      'resolved' => (
          icon: LucideIcons.checkCircle2,
          color: AppColors.leben,
          i18n: 'posts.statusResolved',
        ),
      _ => null, // active → kein Badge
    };
    if (spec == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 9, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.16),
        border: Border.all(color: spec.color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: compact ? 10 : 12, color: spec.color),
          const SizedBox(width: 4),
          Text(spec.i18n.tr(),
              style: AppTypography.label(
                  size: compact ? 8.5 : 10, color: spec.color)),
        ],
      ),
    );
  }
}
