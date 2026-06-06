/// SKILL: mensaena-design
/// DashboardTileError — dezenter Inline-Fehlerzustand für Dashboard-Kacheln.
///
/// Hintergrund: Kacheln blendeten sich bei Fehler still aus
/// (`error: (_, __) => SizedBox.shrink()`). Das ist nicht von einem echten
/// Leerzustand unterscheidbar — der Nutzer denkt „es gibt nichts", obwohl das
/// Laden fehlschlug. Diese Kachel zeigt stattdessen eine SEHR dezente Zeile
/// (eine Höhe wie eine Textzeile, gedämpfte Farben, kein roter Block) mit
/// Tap-to-Retry. Bewusst klein, damit ein flächiger Ausfall (z. B. kurz kein
/// Netz) das Dashboard nicht mit Fehlerblöcken überflutet — der globale
/// Offline-Banner deckt den systemischen Fall ohnehin ab.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class DashboardTileError extends StatelessWidget {
  const DashboardTileError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.refreshCw, size: 13, color: AppColors.mute),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'dashboard.tileLoadError'.tr(),
                style: AppTypography.caption(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
