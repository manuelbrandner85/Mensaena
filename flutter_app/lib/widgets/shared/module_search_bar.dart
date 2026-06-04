import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design
/// Wiederverwendbare Suchleiste — 1:1-Pendant zur Web-`SearchBar` in
/// `src/components/dashboard/`. Cinema-Dark-Style, mit optionalem
/// rechtem Filter-Icon, Clear-Button, und Debounce-Callback.
class ModuleSearchBar extends StatefulWidget {
  const ModuleSearchBar({
    required this.onChanged,
    this.hintText = 'Suchen…',
    this.initialValue = '',
    this.onFilterTap,
    this.showFilterDot = false,
    this.autofocus = false,
    super.key,
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final String initialValue;
  final VoidCallback? onFilterTap;
  final bool showFilterDot;
  final bool autofocus;

  @override
  State<ModuleSearchBar> createState() => _ModuleSearchBarState();
}

class _ModuleSearchBarState extends State<ModuleSearchBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(LucideIcons.search, size: 16, color: AppColors.mute),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              style:
                  AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: AppTypography.body(
                  size: 13,
                  color: AppColors.mute,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            IconButton(
              tooltip: 'common.close'.tr(),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () {
                _ctrl.clear();
                widget.onChanged('');
                setState(() {});
              },
              icon: const Icon(LucideIcons.x,
                  size: 14, color: AppColors.mute),
            ),
          if (widget.onFilterTap != null) ...[
            Container(
              width: 1,
              height: 22,
              color: AppColors.line,
            ),
            Stack(
              children: [
                IconButton(
                  tooltip: 'common.filters'.tr(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 44, minHeight: 44),
                  onPressed: widget.onFilterTap,
                  icon: const Icon(LucideIcons.slidersHorizontal,
                      size: 16, color: AppColors.amber),
                ),
                if (widget.showFilterDot)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
