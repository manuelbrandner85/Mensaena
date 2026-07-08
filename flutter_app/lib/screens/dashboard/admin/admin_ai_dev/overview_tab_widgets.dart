part of '../admin_ai_dev_screen.dart';

// ── „Was als Nächstes?" ──────────────────────────────────────────────────────
// KI-Empfehlung: die Top-Quick-Wins (höchster Nutzen, kleinster Aufwand) ganz
// oben auf der Übersicht — mit Ein-Klick-Umsetzung.
class _NextUpCard extends StatelessWidget {
  const _NextUpCard({
    required this.suggestions,
    required this.busyIds,
    required this.onAccept,
    required this.onSeeAll,
  });
  final List<Map<String, dynamic>> suggestions;
  final Set<String> busyIds;
  final ValueChanged<Map<String, dynamic>> onAccept;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withValues(alpha: 0.10),
            AppColors.amber.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 16, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text('adminDev.nextUp.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w800)),
              ),
              InkWell(
                onTap: onSeeAll,
                child: Text('adminDev.nextUp.seeAll'.tr(),
                    style: AppTypography.label(size: 11, color: AppColors.teal)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('adminDev.nextUp.subtitle'.tr(),
              style: AppTypography.caption(color: AppColors.lightMute)),
          const SizedBox(height: 10),
          ...suggestions.map((s) {
            final id = s['id'] as String? ?? '';
            final busy = busyIds.contains(id);
            final title = (s['title'] as String?)?.trim().isNotEmpty == true
                ? s['title'] as String
                : (s['instruction'] as String? ?? '');
            final impact = (s['impact'] as num?)?.toInt();
            final effort = (s['effort'] as num?)?.toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                                size: 12, color: AppColors.lightInk)),
                        if (impact != null && effort != null)
                          Text(
                            'adminDev.impactEffort'.tr(namedArgs: {
                              'impact': '$impact',
                              'effort': '$effort',
                            }),
                            style: AppTypography.label(
                                size: 9, color: AppColors.lightMute),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FilledButton(
                          onPressed: () => onAccept(s),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('adminDev.nextUp.do'.tr(),
                              style: AppTypography.label(
                                  size: 11, color: Colors.white)),
                        ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Status-Leiste ──────────────────────────────────────────────────────────
// Kompakter Überblick ganz oben: aktive Aufträge, offene Vorschläge, offene
// Alarme und die zuletzt ausgelieferte Änderung — alles auf einen Blick.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.activeTasks,
    required this.openSuggestions,
    required this.openAlerts,
    required this.lastDelivered,
  });
  final int activeTasks;
  final int openSuggestions;
  final int openAlerts;
  final String? lastDelivered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.lightElevated,
        border: Border(
          bottom: BorderSide(color: AppColors.lightLine),
        ),
      ),
      child: Row(
        children: [
          _StatChip(
            icon: LucideIcons.loader,
            label: 'adminDev.statusBar.active'.tr(),
            value: '$activeTasks',
            color: activeTasks > 0 ? AppColors.teal : AppColors.lightMute,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: LucideIcons.lightbulb,
            label: 'adminDev.statusBar.suggestions'.tr(),
            value: '$openSuggestions',
            color: openSuggestions > 0 ? AppColors.amber : AppColors.lightMute,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: LucideIcons.alertTriangle,
            label: 'adminDev.statusBar.alerts'.tr(),
            value: '$openAlerts',
            color: openAlerts > 0 ? AppColors.herzrot : AppColors.lightMute,
          ),
          if (lastDelivered != null && lastDelivered!.isNotEmpty) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(LucideIcons.gitMerge,
                      size: 12, color: AppColors.leben),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      lastDelivered!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTypography.caption(color: AppColors.lightMute),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(value,
              style: AppTypography.label(size: 12, color: color)),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.label(size: 10, color: AppColors.lightMute)),
        ],
      ),
    );
  }
}

// ── Godmode Header ────────────────────────────────────────────────────────────

class _GodmodeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withValues(alpha: 0.10),
            AppColors.teal.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
            bottom: BorderSide(color: AppColors.teal.withValues(alpha: 0.12))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(LucideIcons.zap, size: 16, color: AppColors.teal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'adminDev.subtitle'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.lightMute),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'GODMODE',
              style: AppTypography.body(
                  size: 10, color: Colors.white, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Row ──────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.selectedKey,
    required this.dynamicCategories,
    required this.onSelect,
  });
  final String selectedKey;
  final List<Map<String, dynamic>> dynamicCategories;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    // Eigene Kategorien, die nicht schon Built-in sind (selbstlernend).
    final builtinKeys = _DevCategory.values.map((c) => c.name).toSet();
    final extras = dynamicCategories
        .where((c) => !builtinKeys.contains(c['key']))
        .toList();

    return Container(
      height: 46,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          ..._DevCategory.values.map((cat) => _chip(
                key: cat.name,
                label: cat.i18nKey.tr(),
                icon: cat.icon,
                active: cat.name == selectedKey,
                isNew: false,
              )),
          ...extras.map((c) => _chip(
                key: c['key'] as String? ?? '',
                label: (c['label'] as String?) ?? (c['key'] as String? ?? ''),
                icon: LucideIcons.sparkles,
                active: c['key'] == selectedKey,
                isNew: true,
              )),
        ],
      ),
    );
  }

  Widget _chip({
    required String key,
    required String label,
    required IconData icon,
    required bool active,
    required bool isNew,
  }) {
    return GestureDetector(
      onTap: () => onSelect(key),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.teal : AppColors.lightElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.teal
                : (isNew
                    ? AppColors.teal.withValues(alpha: 0.4)
                    : AppColors.lightLine),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12, color: active ? Colors.white : AppColors.lightMute),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.body(
                size: 12,
                color: active ? Colors.white : AppColors.lightInk,
                weight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Severity Row (Filter) ───────────────────────────────────────────────────

class _SeverityRow extends StatelessWidget {
  const _SeverityRow({required this.selected, required this.onSelect});
  final String selected;
  final void Function(String) onSelect;

  Color _color(String sev) {
    switch (sev) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.deepOrange.shade400;
      case 'medium':
        return AppColors.amber;
      case 'low':
        return AppColors.lightMute;
      default:
        return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _severityFilters.map((sev) {
          final active = sev == selected;
          final c = _color(sev);
          final label = sev == 'all'
              ? 'adminDev.selectAll'.tr()
              : 'adminDev.severity.$sev'.tr();
          return GestureDetector(
            onTap: () => onSelect(sev),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? c.withValues(alpha: 0.14) : AppColors.lightElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? c : AppColors.lightLine,
                ),
              ),
              child: Text(
                label,
                style: AppTypography.body(
                  size: 11,
                  color: active ? c : AppColors.lightMute,
                  weight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Live Scan Card ──────────────────────────────────────────────────────────

// ── Notizen / Backlog (ausklappbar) ─────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  const _NotesCard({
    required this.notes,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onUse,
  });
  final List<Map<String, dynamic>> notes;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String) onDelete;
  final void Function(String id, String content) onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(LucideIcons.scrollText,
                      size: 18, color: AppColors.trust),
                  const SizedBox(width: 10),
                  Text(
                    'adminDev.notes.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.lightRaised,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${notes.length}',
                        style: AppTypography.body(
                            size: 10, color: AppColors.lightMute)),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.lightMute,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text('adminDev.notes.empty'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.lightMute)),
              )
            else
              ...notes.map((n) => _NoteTile(
                    note: n,
                    onEdit: () => onEdit(n),
                    onDelete: () => onDelete(n['id'] as String),
                    onUse: () => onUse(
                          n['id'] as String? ?? '',
                          n['content'] as String? ?? '',
                        ),
                  )),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text('adminDev.notes.add'.tr()),
                style: TextButton.styleFrom(foregroundColor: AppColors.teal),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.onUse,
  });
  final Map<String, dynamic> note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final content = note['content'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.lightElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: AppTypography.body(size: 12, color: AppColors.lightInk),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencil, size: 15),
                color: AppColors.lightMute,
                visualDensity: VisualDensity.compact,
                tooltip: 'adminDev.notes.edit'.tr(),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2, size: 15),
                color: AppColors.lightMute,
                visualDensity: VisualDensity.compact,
                tooltip: 'common.delete'.tr(),
              ),
              TextButton.icon(
                onPressed: onUse,
                icon: const Icon(LucideIcons.send, size: 14),
                label: Text('common.send'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveScanCard extends StatefulWidget {
  const _LiveScanCard({
    required this.scanning,
    required this.scan,
    required this.loading,
    required this.onScan,
  });
  final bool scanning;
  final Map<String, dynamic>? scan;
  final bool loading;
  final VoidCallback onScan;

  @override
  State<_LiveScanCard> createState() => _LiveScanCardState();
}

class _LiveScanCardState extends State<_LiveScanCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  // (c) Einmalig in initState gecacht — nie neu alloziert während build().
  late final Animation<double> _fadePulse; // Scan-Icon: 0.35 → 1.0
  late final Animation<double> _fadeDot; // Fortschritts-Dot: 0.3 → 1.0
  Timer? _tick; // sekündlicher Tick für die Laufzeit-Anzeige

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadePulse = Tween<double>(begin: 0.35, end: 1.0).animate(_ac);
    _fadeDot = Tween<double>(begin: 0.3, end: 1.0).animate(_ac);
    // Pulse-Animation + Sekundentimer NUR bei aktivem Scan — sonst läuft der
    // Ticker (und damit ein Frame-Callback pro Vsync) dauerhaft im Leerlauf.
    _syncScanState();
  }

  @override
  void didUpdateWidget(covariant _LiveScanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanning != widget.scanning) _syncScanState();
  }

  // Startet/stoppt Pulse-Animation und Laufzeit-Timer passend zum Scan-Status.
  void _syncScanState() {
    if (widget.scanning) {
      if (!_ac.isAnimating) _ac.repeat(reverse: true);
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && widget.scanning) setState(() {});
      });
    } else {
      _ac.stop();
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    _tick?.cancel();
    super.dispose();
  }

  // Laufzeit seit Scan-Start als mm:ss (aus created_at).
  String _elapsed(Map<String, dynamic>? scan) {
    final raw = scan?['created_at'] as String?;
    if (raw == null) return '';
    final start = DateTime.tryParse(raw)?.toUtc();
    if (start == null) return '';
    final secs = DateTime.now().toUtc().difference(start.toUtc()).inSeconds;
    if (secs < 0) return '';
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final scanning = widget.scanning;
    final currentFile = scan?['current_file'] as String?;
    final phase = scan?['phase'] as String?;
    final analyzed = (scan?['analyzed_files'] as num?)?.toInt() ?? 0;
    final foundSoFar = (scan?['found_so_far'] as num?)?.toInt() ?? 0;
    final found = (scan?['found'] as num?)?.toInt() ?? 0;
    final isDone = (scan?['status'] as String?) == 'done';
    final elapsed = scanning ? _elapsed(scan) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: scanning ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.teal.withValues(alpha: scanning ? 0.35 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              scanning
                  ? FadeTransition(
                      opacity: _fadePulse,
                      child: const Icon(LucideIcons.scanLine,
                          size: 20, color: AppColors.teal),
                    )
                  : const Icon(LucideIcons.scanLine,
                      size: 20, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'adminDev.scanTitle'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.lightInk,
                          weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scanning
                          ? 'adminDev.scanWorking'.tr()
                          : (isDone
                              ? 'adminDev.lastScan'
                                  .tr(namedArgs: {'count': '$found'})
                              : 'adminDev.scanHint'.tr()),
                      style: AppTypography.body(
                          size: 11, color: AppColors.lightMute),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (scanning || widget.loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.teal),
                )
              else
                FilledButton.icon(
                  onPressed: widget.onScan,
                  icon: const Icon(LucideIcons.scanLine, size: 14),
                  label: Text('adminDev.scanButton'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          // Live-Fortschritt: aktuelle Datei + Zähler.
          if (scanning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  FadeTransition(
                    opacity: _fadeDot,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (currentFile != null && currentFile.isNotEmpty)
                          ? 'adminDev.scanAnalyzing'
                              .tr(namedArgs: {'file': currentFile})
                          : 'adminDev.scanWorking'.tr(),
                      style: AppTypography.body(
                          size: 11, color: AppColors.lightInk),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.fileSearch,
                    size: 12, color: AppColors.lightMute),
                const SizedBox(width: 4),
                Text(
                  'adminDev.scanFilesRead'.tr(namedArgs: {'count': '$analyzed'}),
                  style:
                      AppTypography.body(size: 10, color: AppColors.lightMute),
                ),
                if (foundSoFar > 0) ...[
                  const SizedBox(width: 12),
                  const Icon(LucideIcons.sparkles,
                      size: 12, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text(
                    'adminDev.scanFoundSoFar'
                        .tr(namedArgs: {'count': '$foundSoFar'}),
                    style:
                        AppTypography.body(size: 10, color: AppColors.teal),
                  ),
                ],
                const Spacer(),
                if (elapsed.isNotEmpty) ...[
                  const Icon(LucideIcons.clock,
                      size: 12, color: AppColors.lightMute),
                  const SizedBox(width: 4),
                  Text(elapsed,
                      style: AppTypography.body(
                          size: 10, color: AppColors.lightMute)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Aktuelle Phase + Beruhigungs-Hinweis (Audit dauert ein paar Min.).
            Text(
              (phase != null && phase.isNotEmpty)
                  ? 'adminDev.scanPhase'.tr(namedArgs: {'phase': phase})
                  : 'adminDev.scanLongHint'.tr(),
              style: AppTypography.body(size: 10, color: AppColors.lightMute),
            ),
          ],
        ],
      ),
    );
  }
}
