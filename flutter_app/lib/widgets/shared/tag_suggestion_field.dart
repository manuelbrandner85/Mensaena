/// SKILL: mensaena-features + mensaena-design
/// Tag-Eingabe mit antippbaren Vorschlags-Chips. Erweitert die bisherige
/// Freitext-Komma-Eingabe um schnelle Vorschläge — weniger Tippen, mehr
/// konsistente Tags. Schreibt komma-getrennt in [controller] (kompatibel
/// zur bestehenden `_tagsCtrl.text.split(',')`-Logik der Create-Screens).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class TagSuggestionField extends StatefulWidget {
  const TagSuggestionField({
    required this.controller,
    required this.suggestions,
    this.label,
    this.hint,
    this.maxTags = 8,
    super.key,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String? label;
  final String? hint;
  final int maxTags;

  @override
  State<TagSuggestionField> createState() => _TagSuggestionFieldState();
}

class _TagSuggestionFieldState extends State<TagSuggestionField> {
  List<String> get _current => widget.controller.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  void _toggle(String tag) {
    final cur = _current;
    final lower = cur.map((t) => t.toLowerCase()).toList();
    if (lower.contains(tag.toLowerCase())) {
      cur.removeWhere((t) => t.toLowerCase() == tag.toLowerCase());
    } else {
      if (cur.length >= widget.maxTags) return;
      cur.add(tag);
    }
    widget.controller.text = cur.join(', ');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    final curLower = cur.map((t) => t.toLowerCase()).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!.toUpperCase(),
              style: AppTypography.label(size: 10, color: AppColors.mute)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: widget.controller,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: widget.hint ?? 'create.tagsHint'.tr(),
            hintStyle: AppTypography.caption(),
            prefixIcon:
                const Icon(LucideIcons.hash, size: 16, color: AppColors.mute),
            filled: true,
            fillColor: AppColors.elevated,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('create.tagSuggestions'.tr(),
            style: AppTypography.label(size: 9, color: AppColors.mute)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in widget.suggestions)
              _SuggChip(
                label: s,
                selected: curLower.contains(s.toLowerCase()),
                onTap: () => _toggle(s),
              ),
          ],
        ),
      ],
    );
  }
}

class _SuggChip extends StatelessWidget {
  const _SuggChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.bronze.withValues(alpha: 0.18)
              : AppColors.elevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.bronze.withValues(alpha: 0.5)
                : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? LucideIcons.check : LucideIcons.plus,
              size: 12,
              color: selected ? AppColors.bronze : AppColors.mute,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.body(
                size: 12,
                color: selected ? AppColors.bronze : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
