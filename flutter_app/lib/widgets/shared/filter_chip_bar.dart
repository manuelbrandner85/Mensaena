import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design
/// Horizontaler Filter-Chip-Bar — Pendant zur Web-`FilterPills`.
/// Optional mit "Alle"-Reset. Mehrfachauswahl moeglich.
class FilterChipBar<T> extends StatelessWidget {
  const FilterChipBar({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiSelect = false,
    this.allowAll = true,
    this.allLabel = 'Alle',
    super.key,
  });

  final List<FilterOption<T>> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multiSelect;
  final bool allowAll;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (allowAll) ...[
            _Pill(
              label: allLabel,
              active: selected.isEmpty,
              onTap: () => onChanged(<T>{}),
            ),
            const SizedBox(width: 6),
          ],
          for (final opt in options) ...[
            _Pill(
              label: opt.label,
              icon: opt.icon,
              active: selected.contains(opt.value),
              onTap: () {
                final next = <T>{...selected};
                if (multiSelect) {
                  if (next.contains(opt.value)) {
                    next.remove(opt.value);
                  } else {
                    next.add(opt.value);
                  }
                } else {
                  if (next.contains(opt.value)) {
                    next.clear();
                  } else {
                    next
                      ..clear()
                      ..add(opt.value);
                  }
                }
                onChanged(next);
              },
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class FilterOption<T> {
  const FilterOption({
    required this.value,
    required this.label,
    this.icon,
  });
  final T value;
  final String label;
  final IconData? icon;
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppColors.amber.withValues(alpha: 0.18)
              : AppColors.elevated,
          border: Border.all(
            color: active
                ? AppColors.amber.withValues(alpha: 0.6)
                : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 11,
                  color: active ? AppColors.amber : AppColors.inkSoft),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.label(
                size: 10,
                color: active ? AppColors.amber : AppColors.inkSoft,
              ),
            ),
            if (active && icon == null) ...[
              const SizedBox(width: 4),
              const Icon(LucideIcons.check,
                  size: 11, color: AppColors.amber),
            ],
          ],
        ),
      ),
    );
  }
}

/// Active-Filter-Chip-Strip mit Clear-Button — Pendant zu Web's
/// "Aktive Filter" Strip in `posts/page.tsx`.
class ActiveFilterStrip extends StatelessWidget {
  const ActiveFilterStrip({
    required this.chips,
    required this.onClearAll,
    super.key,
  });

  final List<ActiveFilterChip> chips;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in chips) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.16),
                        border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            c.label,
                            style: AppTypography.label(
                              size: 9,
                              color: AppColors.amber,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: c.onRemove,
                            child: const Icon(LucideIcons.x,
                                size: 11, color: AppColors.amber),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onClearAll,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text('Zurücksetzen',
                style:
                    AppTypography.label(size: 9, color: AppColors.mute)),
          ),
        ],
      ),
    );
  }
}

class ActiveFilterChip {
  const ActiveFilterChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;
}
