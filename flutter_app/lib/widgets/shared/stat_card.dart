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
        // Dezenter Verlauf + Akzent-Tönung oben → mehr Tiefe als flach.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.07),
            AppColors.surface.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.30),
                      blurRadius: 14,
                      spreadRadius: -4,
                    ),
                  ],
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
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(4),
              ),
            )
          else
            Text(
              value,
              style: AppTypography.mono(
                size: 24,
                weight: FontWeight.w700,
              ).copyWith(color: AppColors.ink),
            ),
        ],
      ),
    );
  }
}
