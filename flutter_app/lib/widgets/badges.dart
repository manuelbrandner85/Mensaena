import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Badge-Komponenten – matchen .badge-green, .badge-blue, .badge-red, etc.

enum BadgeColor { green, blue, red, orange, gray, purple }

class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = BadgeColor.green,
    this.icon,
  });

  final String label;
  final BadgeColor color;
  final IconData? icon;

  ({Color bg, Color fg}) get _palette {
    switch (color) {
      case BadgeColor.green:
        return (bg: AppColors.primary100, fg: AppColors.primary800);
      case BadgeColor.blue:
        return (bg: AppColors.trust100, fg: AppColors.trust600);
      case BadgeColor.red:
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
      case BadgeColor.orange:
        return (bg: const Color(0xFFFFEDD5), fg: const Color(0xFFC2410C));
      case BadgeColor.gray:
        return (bg: AppColors.stone100, fg: AppColors.ink700);
      case BadgeColor.purple:
        return (bg: const Color(0xFFEDE9FE), fg: const Color(0xFF6D28D9));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: p.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: p.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: const BoxDecoration(
        color: AppColors.emergency500,
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
