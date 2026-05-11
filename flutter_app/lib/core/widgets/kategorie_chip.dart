import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

enum PostKategorie {
  hilfeAnbieten,
  hilfeSuchen,
  werkzeug,
  veranstaltung,
  tausch,
  mitfahrt,
  krisenhilfe,
  tierisches,
  wohnungsmarkt,
  allgemein,
}

class _KatStyle {
  final Color color;
  final IconData icon;
  final String label;
  const _KatStyle(this.color, this.icon, this.label);
}

const Map<PostKategorie, _KatStyle> _styles = {
  PostKategorie.hilfeAnbieten: _KatStyle(MnColors.amber, LucideIcons.heart, 'Hilfe anbieten'),
  PostKategorie.hilfeSuchen: _KatStyle(MnColors.teal, LucideIcons.helpingHand, 'Hilfe suchen'),
  PostKategorie.werkzeug: _KatStyle(MnColors.trust, LucideIcons.wrench, 'Werkzeug'),
  PostKategorie.veranstaltung: _KatStyle(MnColors.tealSoft, LucideIcons.calendar, 'Veranstaltung'),
  PostKategorie.tausch: _KatStyle(MnColors.amberSoft, LucideIcons.gift, 'Tausch'),
  PostKategorie.mitfahrt: _KatStyle(MnColors.inkSoft, LucideIcons.car, 'Mitfahrt'),
  PostKategorie.krisenhilfe: _KatStyle(MnColors.herzrot, LucideIcons.alertTriangle, 'Krisenhilfe'),
  PostKategorie.tierisches: _KatStyle(MnColors.amberWarm, LucideIcons.dog, 'Tiere'),
  PostKategorie.wohnungsmarkt: _KatStyle(MnColors.teal, LucideIcons.home, 'Wohnen'),
  PostKategorie.allgemein: _KatStyle(MnColors.mute, LucideIcons.messageCircle, 'Allgemein'),
};

class KategorieChip extends StatelessWidget {
  final PostKategorie kategorie;
  final bool selected;
  final bool isCrisis;
  final VoidCallback? onTap;

  const KategorieChip({
    super.key,
    required this.kategorie,
    this.selected = false,
    this.isCrisis = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = _styles[kategorie]!;
    final color = style.color;
    final pulse = isCrisis && kategorie == PostKategorie.krisenhilfe;

    final content = AnimatedContainer(
      duration: MnDimensions.durFast,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.18 : 0.10),
        border: Border.all(
          color: color.withValues(alpha: selected ? 0.5 : 0.20),
          width: pulse ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(MnDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            style.label.toUpperCase(),
            style: MnTypography.label(color: color),
          ),
        ],
      ),
    );

    return Semantics(
      label: style.label,
      button: onTap != null,
      selected: selected,
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(MnDimensions.radiusPill),
              onTap: onTap,
              child: content,
            ),
    );
  }
}
