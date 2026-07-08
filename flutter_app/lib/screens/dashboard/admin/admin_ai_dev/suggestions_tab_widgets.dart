part of '../admin_ai_dev_screen.dart';

// ── Suggestions Header (mit Mehrfachauswahl-Toggle) ─────────────────────────

class _SuggestionsHeader extends StatelessWidget {
  const _SuggestionsHeader({
    required this.count,
    required this.selectionMode,
    required this.selectedCount,
    required this.onToggleMode,
    required this.onSelectAll,
  });
  final int count;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onToggleMode;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, size: 14, color: AppColors.lightMute),
          const SizedBox(width: 6),
          Text(
            'adminDev.suggestions'.tr(),
            style: AppTypography.body(
                size: 12, color: AppColors.lightMute, weight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.lightRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style:
                    AppTypography.body(size: 10, color: AppColors.lightMute)),
          ),
          const Spacer(),
          if (selectionMode)
            TextButton(
              onPressed: onSelectAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
              ),
              child: Text('adminDev.selectAll'.tr(),
                  style: const TextStyle(fontSize: 12)),
            ),
          TextButton.icon(
            onPressed: onToggleMode,
            icon: Icon(
                selectionMode ? LucideIcons.x : LucideIcons.checkCircle2,
                size: 13),
            label: Text(
              selectionMode ? 'adminDev.cancel'.tr() : 'adminDev.select'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor:
                  selectionMode ? AppColors.lightMute : AppColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(
      {required this.icon,
      required this.label,
      required this.count,
      this.trailing});
  final IconData icon;
  final String label;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.lightMute),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.body(
                size: 12, color: AppColors.lightMute, weight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.lightRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style:
                    AppTypography.body(size: 10, color: AppColors.lightMute)),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

// Kleiner „Abgeschlossene löschen"-Button im Aufträge-Header.
class _ClearTasksButton extends StatelessWidget {
  const _ClearTasksButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.lightMute),
              )
            else
              const Icon(LucideIcons.trash2, size: 12, color: AppColors.lightMute),
            const SizedBox(width: 4),
            Text('adminDev.clearDone'.tr(),
                style:
                    AppTypography.body(size: 11, color: AppColors.lightMute)),
          ],
        ),
      ),
    );
  }
}

// ── Suggestion Card ───────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.categoryLabel,
    required this.busy,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelect,
    required this.onAccept,
    required this.onReject,
  });
  final Map<String, dynamic> suggestion;
  final String categoryLabel;
  final bool busy;
  final bool selectionMode;
  final bool selected;
  final void Function(String) onToggleSelect;
  final void Function(Map<String, dynamic>) onAccept;
  final void Function(String) onReject;

  @override
  Widget build(BuildContext context) {
    final id = suggestion['id'] as String? ?? '';
    final title = suggestion['title'] as String? ?? '';
    final description = suggestion['description'] as String? ?? '';
    final reason = suggestion['reason'] as String?;
    final kind = suggestion['kind'] as String? ?? 'improvement';
    final severity = suggestion['severity'] as String? ?? 'medium';
    final fileHint = suggestion['file_hint'] as String?;
    final sevColor = _severityColor(severity);
    final kindColor = _kindColor(kind);
    final kindIcon = _kindIcon(kind);
    final impact = (suggestion['impact'] as num?)?.toInt();
    final effort = (suggestion['effort'] as num?)?.toInt();
    final quickWin =
        impact != null && effort != null && impact >= 4 && effort <= 2;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppColors.teal.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: selected ? AppColors.teal : AppColors.lightLine),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? LucideIcons.checkSquare
                      : LucideIcons.circle,
                  size: 18,
                  color: selected ? AppColors.teal : AppColors.lightMute,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Typ-Marker zuerst (Bug/Neuerung/Verbesserung) mit Icon.
                    _KindBadge(
                        text: 'adminDev.kind.$kind'.tr(),
                        color: kindColor,
                        icon: kindIcon),
                    _Badge(text: categoryLabel, color: AppColors.teal),
                    _Badge(
                        text: 'adminDev.severity.$severity'.tr(),
                        color: sevColor),
                    if (quickWin)
                      _Badge(
                          text: 'adminDev.quickWin'.tr(),
                          color: AppColors.leben),
                    if (impact != null && effort != null)
                      _Badge(
                        text: 'adminDev.impactEffort'.tr(namedArgs: {
                          'impact': '$impact',
                          'effort': '$effort',
                        }),
                        color: AppColors.bronze,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.body(
                size: 13, color: AppColors.lightInk, weight: FontWeight.w600),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTypography.body(size: 12, color: AppColors.lightMute),
            ),
          ],
          // „Warum" — leicht verständliche Begründung.
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.lightbulb,
                      size: 13, color: AppColors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.body(
                            size: 11, color: AppColors.lightInk),
                        children: [
                          TextSpan(
                            text: '${'adminDev.why'.tr()}: ',
                            style: AppTypography.body(
                                size: 11,
                                color: AppColors.lightInk,
                                weight: FontWeight.w700),
                          ),
                          TextSpan(text: reason),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (fileHint != null && fileHint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.scrollText,
                    size: 11, color: AppColors.lightMute),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fileHint,
                    style: AppTypography.body(
                        size: 10, color: AppColors.lightMute),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          // Im Auswahlmodus keine Einzel-Buttons (Sammel-Aktion über die Leiste).
          if (!selectionMode) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => onAccept(suggestion),
                    icon: busy
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.check, size: 14),
                    label: Text('adminDev.accept'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => onReject(id),
                  icon: const Icon(LucideIcons.x, size: 14),
                  label: Text('adminDev.reject'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.lightMute,
                    side: BorderSide(color: AppColors.lightLine),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!selectionMode) return card;
    return GestureDetector(
      onTap: () => onToggleSelect(id),
      child: card,
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.deepOrange.shade400;
      case 'medium':
        return AppColors.amber;
      default:
        return AppColors.lightMute;
    }
  }

  Color _kindColor(String kind) {
    switch (kind) {
      case 'bug':
        return Colors.red.shade700;
      case 'new':
        return Colors.indigo.shade400;
      default: // improvement
        return AppColors.teal;
    }
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'bug':
        return LucideIcons.bug;
      case 'new':
        return LucideIcons.sparkles;
      default: // improvement
        return LucideIcons.settings;
    }
  }
}

// Typ-Marker mit Icon (Bug/Neuerung/Verbesserung).
class _KindBadge extends StatelessWidget {
  const _KindBadge(
      {required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: AppTypography.body(
                size: 10, color: color, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style:
            AppTypography.body(size: 10, color: color, weight: FontWeight.w600),
      ),
    );
  }
}

// ── Batch-Aktionsleiste ──────────────────────────────────────────────────────

class _BatchBar extends StatelessWidget {
  const _BatchBar({
    required this.count,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });
  final int count;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: AppColors.teal.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Text(
            'adminDev.selectedCount'.tr(namedArgs: {'count': '$count'}),
            style: AppTypography.body(
                size: 12, color: AppColors.lightInk, weight: FontWeight.w600),
          ),
          const Spacer(),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.teal),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(LucideIcons.x, size: 14),
              label: Text('adminDev.reject'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.lightMute,
                side: BorderSide(color: AppColors.lightLine),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAccept,
              icon: const Icon(LucideIcons.check, size: 14),
              label: Text('adminDev.accept'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty Hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(LucideIcons.bot, size: 40, color: AppColors.teal),
          const SizedBox(height: 10),
          Text(
            'adminDev.empty'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 13, color: AppColors.lightMute),
          ),
        ],
      ),
    );
  }
}
