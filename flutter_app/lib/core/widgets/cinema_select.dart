import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

class CinemaSelectOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const CinemaSelectOption({required this.value, required this.label, this.icon});
}

class CinemaSelect<T> extends StatelessWidget {
  final List<CinemaSelectOption<T>> options;
  final T? value;
  final String? placeholder;
  final String? label;
  final ValueChanged<T>? onChanged;

  const CinemaSelect({
    super.key,
    required this.options,
    this.value,
    this.placeholder,
    this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = options.where((o) => o.value == value).cast<CinemaSelectOption<T>?>().firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: MnTypography.label(color: MnColors.mute)),
          const SizedBox(height: 6),
        ],
        DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: MnColors.raised,
            iconEnabledColor: MnColors.mute,
            icon: const Icon(LucideIcons.chevronDown, size: 18),
            borderRadius: BorderRadius.circular(MnDimensions.radiusInput),
            hint: Text(
              placeholder ?? 'Bitte waehlen',
              style: MnTypography.body(color: MnColors.ghost),
            ),
            style: MnTypography.body(color: MnColors.ink),
            items: options
                .map(
                  (o) => DropdownMenuItem<T>(
                    value: o.value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (o.icon != null) ...[
                          Icon(o.icon, size: 16, color: MnColors.mute),
                          const SizedBox(width: 8),
                        ],
                        Text(o.label, style: MnTypography.body(color: MnColors.ink)),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged == null ? null : (v) { if (v != null) onChanged!(v); },
            selectedItemBuilder: (_) => options
                .map(
                  (o) => Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: MnColors.surface,
                      borderRadius: BorderRadius.circular(MnDimensions.radiusInput),
                      border: Border.all(color: MnColors.line),
                    ),
                    child: Text(
                      selected?.label ?? '',
                      style: MnTypography.body(color: MnColors.ink),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
