import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design
/// Statistik-Kachel fuer Dashboard-Home. Icon + Label + Wert.
/// Loading- und Error-State integriert.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.amber,
    this.loading = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: AppTypography.label(size: 10),
          ),
          const SizedBox(height: 6),
          if (loading)
            Container(
              width: 40,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          else
            Text(
              value,
              style: AppTypography.mono(
                size: 22,
                weight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
