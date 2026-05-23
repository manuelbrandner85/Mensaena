import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design
/// Editorial-Header — 1:1-Pendant zu Web's
/// `meta-label + page-title + page-subtitle + divider-gradient`
/// (siehe `src/app/dashboard/posts/page.tsx` Z.250-279 und alle anderen
/// `header` Blocks in dashboard/*/page.tsx).
///
/// Aufbau:
///   § <index> / <kategorie>     ← meta-label, bronze, uppercase, tracking-wide
///   Page-Title                  ← display-Serif, gross
///   Subtitle                    ← muted, kleiner
///                               ← (rechts, optional: Action-Pills)
///   ───────                     ← Gradient-Divider unten
class EditorialModuleHeader extends StatelessWidget {
  const EditorialModuleHeader({
    required this.metaIndex,
    required this.metaCategory,
    required this.title,
    this.subtitle,
    this.actions,
    super.key,
  });

  /// z.B. "§ 5"
  final String metaIndex;

  /// z.B. "Beiträge"
  final String metaCategory;

  /// z.B. "Alle Beiträge"
  final String title;

  /// z.B. "12 aktiv in deiner Nähe"
  final String? subtitle;

  /// Optional rechts ausgerichtete Action-Buttons.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meta-Label "§ X / Kategorie"
        Row(
          children: [
            Container(
              width: 16,
              height: 1,
              color: AppColors.bronze.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 6),
            Text(
              '$metaIndex / $metaCategory',
              style: AppTypography.label(
                size: 9,
                color: AppColors.bronze.withValues(alpha: 0.85),
                letterSpacing: 0.20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Title + Actions
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.display(
                      size: 26,
                      color: AppColors.ink,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.mute,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (actions != null) ...[
              const SizedBox(width: 8),
              ...actions!,
            ],
          ],
        ),
        const SizedBox(height: 14),
        // Gradient-Divider
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.bronze.withValues(alpha: 0.3),
                AppColors.bronze.withValues(alpha: 0.10),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Compact Action-Pill — Pendant zu Web's
/// "px-4 py-2 rounded-full text-xs font-semibold tracking-wide border"
class EditorialPillButton extends StatelessWidget {
  const EditorialPillButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.active = false,
    this.color,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.bronze;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.10)
                : AppColors.voidColor,
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 12,
                  color: active ? accent : AppColors.inkSoft,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: AppTypography.label(
                  size: 10,
                  color: active ? accent : AppColors.inkSoft,
                  letterSpacing: 0.10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
