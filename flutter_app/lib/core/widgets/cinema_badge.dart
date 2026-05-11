import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

enum BadgeVariant { amber, teal, herzrot, leben, trust, mute }

class CinemaBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  const CinemaBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.amber,
    this.icon,
  });

  Color get _color {
    switch (variant) {
      case BadgeVariant.amber: return MnColors.amber;
      case BadgeVariant.teal: return MnColors.teal;
      case BadgeVariant.herzrot: return MnColors.herzrot;
      case BadgeVariant.leben: return MnColors.leben;
      case BadgeVariant.trust: return MnColors.trust;
      case BadgeVariant.mute: return MnColors.mute;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        border: Border.all(color: c.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(MnDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 6),
          ],
          Text(label, style: MnTypography.label(size: 11, color: c)),
        ],
      ),
    );
  }
}
