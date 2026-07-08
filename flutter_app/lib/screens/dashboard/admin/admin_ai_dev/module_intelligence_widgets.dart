part of '../admin_ai_dev_screen.dart';

// ── Modul-Intelligenz ────────────────────────────────────────────────────────

class _ModuleIntelligenceCard extends StatelessWidget {
  const _ModuleIntelligenceCard({
    required this.insights,
    required this.scan,
    required this.expanded,
    required this.loading,
    required this.busyIds,
    required this.onToggle,
    required this.onScan,
    required this.onAccept,
    required this.onDismiss,
  });

  final List<Map<String, dynamic>> insights;
  final Map<String, dynamic>? scan;
  final bool expanded;
  final bool loading;
  final Set<String> busyIds;
  final VoidCallback onToggle;
  final VoidCallback onScan;
  final void Function(String) onAccept;
  final void Function(String) onDismiss;

  bool get _scanning {
    final s = scan?['status'] as String?;
    return s == 'queued' || s == 'running';
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical':
        return Colors.red.shade600;
      case 'high':
        return Colors.orange.shade600;
      case 'medium':
        return Colors.amber.shade700;
      default:
        return AppColors.leben;
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'vulnerability':
        return Colors.red.shade600;
      case 'new_module':
        return Colors.indigo.shade500;
      case 'extension':
        return Colors.purple.shade500;
      case 'inspiration':
        return Colors.blue.shade500;
      default:
        return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = insights.length;
    final scanDone = scan?['status'] == 'done';
    final insightsCount = scan?['insights_count'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.brain,
                        size: 16, color: Colors.indigo.shade500),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'adminDev.modules.title'.tr(),
                          style: AppTypography.body(
                                  size: 13, color: AppColors.lightInk)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (_scanning)
                          Text(
                            'adminDev.modules.scanning'.tr(),
                            style: AppTypography.body(
                                size: 11, color: AppColors.lightMute),
                          )
                        else if (scanDone && insightsCount > 0)
                          Text(
                            'adminDev.modules.scanDone'
                                .tr(namedArgs: {'count': '$insightsCount'}),
                            style: AppTypography.body(
                                size: 11, color: AppColors.lightMute),
                          )
                        else
                          Text(
                            'adminDev.modules.subtitle'.tr(),
                            style: AppTypography.body(
                                size: 11, color: AppColors.lightMute),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (count > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: AppTypography.body(
                            size: 11, color: Colors.indigo.shade600),
                      ),
                    ),
                  if (_scanning)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onScan,
                      icon: const Icon(LucideIcons.sparkles, size: 13),
                      label: Text('adminDev.modules.scanStart'.tr(),
                          style: AppTypography.body(size: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.indigo.shade600,
                        side: BorderSide(color: Colors.indigo.shade200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.lightMute,
                  ),
                ],
              ),
            ),
          ),
          // Body
          if (expanded) ...[
            const Divider(height: 1),
            if (loading && insights.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (insights.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'adminDev.modules.empty'.tr(),
                  style: AppTypography.body(
                      size: 12, color: AppColors.lightMute),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: insights.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final ins = insights[i];
                  final id = ins['id'] as String? ?? '';
                  final busy = busyIds.contains(id);
                  return _ModuleInsightCard(
                    insight: ins,
                    busy: busy,
                    severityColor: _severityColor(
                        ins['severity'] as String? ?? 'medium'),
                    typeColor:
                        _typeColor(ins['insight_type'] as String? ?? ''),
                    onAccept: () => onAccept(id),
                    onDismiss: () => onDismiss(id),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _ModuleInsightCard extends StatelessWidget {
  const _ModuleInsightCard({
    required this.insight,
    required this.busy,
    required this.severityColor,
    required this.typeColor,
    required this.onAccept,
    required this.onDismiss,
  });

  final Map<String, dynamic> insight;
  final bool busy;
  final Color severityColor;
  final Color typeColor;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final module = insight['module_name'] as String? ?? '';
    final type = insight['insight_type'] as String? ?? 'improvement';
    final severity = insight['severity'] as String? ?? 'medium';
    final title = insight['title'] as String? ?? '';
    final description = insight['description'] as String? ?? '';
    final source = insight['source'] as String? ?? 'analysis';
    final refUrl = insight['reference_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module + type + severity badges
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  module,
                  style: AppTypography.body(
                      size: 10, color: AppColors.teal),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'adminDev.modules.types.$type'.tr(),
                  style: AppTypography.body(size: 10, color: typeColor),
                ),
              ),
              const Spacer(),
              // Severity dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: severityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'adminDev.severity.$severity'.tr(),
                style: AppTypography.body(
                    size: 10, color: AppColors.lightMute),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: AppTypography.body(size: 12, color: AppColors.lightInk)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              description,
              style:
                  AppTypography.body(size: 11, color: AppColors.lightMute),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Source + ref
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                source == 'github'
                    ? LucideIcons.github
                    : source == 'research'
                        ? LucideIcons.search
                        : LucideIcons.terminal,
                size: 11,
                color: AppColors.lightMute,
              ),
              const SizedBox(width: 4),
              Text(
                'adminDev.modules.sources.$source'.tr(),
                style: AppTypography.body(
                    size: 10, color: AppColors.lightMute),
              ),
              if (refUrl != null && refUrl.isNotEmpty) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => safeLaunch(refUrl),
                  child: Text(
                    '↗',
                    style: AppTypography.body(
                        size: 11, color: AppColors.teal),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Actions
          if (busy)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(LucideIcons.x, size: 12),
                    label: Text('adminDev.modules.dismiss'.tr(),
                        style: AppTypography.body(size: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.lightMute,
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(LucideIcons.play, size: 12),
                    label: Text('adminDev.modules.accept'.tr(),
                        style: AppTypography.body(
                            size: 11, color: Colors.white)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo.shade500,
                      padding:
                          const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Findet einen Auftrag mit starker Wortüberschneidung zu [text] in [existing]
// (Duplikat-/Konflikt-Erkennung). Gibt den (gekürzten) Treffer zurück oder null.
/// Wählt automatisch das am besten passende Epic für einen Vorschlag — per
/// Wort-Überlappung zwischen Vorschlag (Titel + Instruction) und Epic
/// (Titel + Beschreibung). Liefert die Epic-ID oder null (keine klare Zuordnung).
String? _bestEpicIdFor(
    Map<String, dynamic> suggestion, List<Map<String, dynamic>> epics) {
  if (epics.isEmpty) return null;
  Set<String> tokens(String? s) => (s ?? '')
      .toLowerCase()
      .split(RegExp(r'\W+'))
      .where((w) => w.length > 3)
      .toSet();
  final sugTokens = tokens(suggestion['title'] as String?)
    ..addAll(tokens(suggestion['instruction'] as String?));
  if (sugTokens.isEmpty) return null;
  String? bestId;
  var bestOverlap = 0;
  for (final e in epics) {
    if ((e['status'] as String?) == 'archived') continue;
    final epicTokens = tokens(e['title'] as String?)
      ..addAll(tokens(e['description'] as String?));
    final overlap = sugTokens.intersection(epicTokens).length;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      bestId = e['id'] as String?;
    }
  }
  // Mindestens 2 gemeinsame Wörter für eine sinnvolle Zuordnung.
  return bestOverlap >= 2 ? bestId : null;
}

/// Relative Zeitangabe ("vor 3 min", "vor 2 h", "vor 4 d") aus ISO-Timestamp.
String? _relativeTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 60) return 'adminDev.time.now'.tr();
  if (diff.inMinutes < 60) {
    return 'adminDev.time.min'.tr(namedArgs: {'n': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return 'adminDev.time.hour'.tr(namedArgs: {'n': '${diff.inHours}'});
  }
  return 'adminDev.time.day'.tr(namedArgs: {'n': '${diff.inDays}'});
}

/// Kurzes Label für die Modell-ID eines Auftrags (Badge im Dashboard).
String? _modelShortLabel(String? id) {
  if (id == null || id.isEmpty) return null;
  if (id.contains('opus')) return 'Opus';
  if (id.contains('sonnet')) return 'Sonnet';
  if (id.contains('haiku')) return 'Haiku';
  return null;
}

String? similarInstruction(String text, Iterable<String> existing) {
  if (text.length < 10) return null;
  final words =
      text.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 4).toSet();
  if (words.isEmpty) return null;
  for (final instr in existing) {
    final ew = instr
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 4)
        .toSet();
    final overlap = words.intersection(ew).length;
    if (overlap >= 3 && overlap / words.length > 0.4) {
      return instr.length > 60 ? '${instr.substring(0, 60)}…' : instr;
    }
  }
  return null;
}
