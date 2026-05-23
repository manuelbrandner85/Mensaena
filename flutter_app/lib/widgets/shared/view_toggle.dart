import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design
/// Segmented-Control fuer View-Toggle (Liste / Karte / Kalender etc.) —
/// Pendant zu Web-`ViewToggle` aus Events/Crisis/Marketplace/Supply.
class ViewToggle<T> extends StatelessWidget {
  const ViewToggle({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<ViewToggleOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opt in options)
            GestureDetector(
              onTap: () => onChanged(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: opt.value == value
                      ? AppColors.amber.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.icon,
                      size: 13,
                      color: opt.value == value
                          ? AppColors.amber
                          : AppColors.inkSoft,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      opt.label,
                      style: AppTypography.label(
                        size: 10,
                        color: opt.value == value
                            ? AppColors.amber
                            : AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ViewToggleOption<T> {
  const ViewToggleOption({
    required this.value,
    required this.label,
    required this.icon,
  });
  final T value;
  final String label;
  final IconData icon;
}
