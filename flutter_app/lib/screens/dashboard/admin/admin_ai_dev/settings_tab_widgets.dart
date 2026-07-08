part of '../admin_ai_dev_screen.dart';

// ── Health-/Metrics-Dashboard ───────────────────────────────────────────────

// Freie-API-Key-Verwaltung (Klapp-Karte). Zeigt NUR Metadaten, nie den Key.
class _ApiKeysCard extends StatelessWidget {
  const _ApiKeysCard({
    required this.keys,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final List<Map<String, dynamic>> keys;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String service) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(LucideIcons.keyRound,
                      size: 16, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('adminDev.apiKeys.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.lightInk,
                            weight: FontWeight.w700)),
                  ),
                  if (keys.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('${keys.length}',
                          style: AppTypography.label(
                              size: 10, color: AppColors.lightMute)),
                    ),
                  Icon(
                      expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.lightMute),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (keys.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('adminDev.apiKeys.empty'.tr(),
                    style: AppTypography.caption()),
              )
            else
              ...keys.map((k) {
                final service = k['service'] as String? ?? '';
                final exp = k['expires_at'] != null
                    ? DateTime.tryParse(k['expires_at'] as String)
                    : null;
                final expired =
                    exp != null && exp.isBefore(DateTime.now());
                return Padding(
                  padding: const EdgeInsets.fromLTRB(13, 6, 6, 6),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.key,
                          size: 13, color: AppColors.lightMute),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service,
                                style: AppTypography.body(
                                    size: 12, color: AppColors.lightInk)),
                            if (exp != null)
                              Text(
                                'adminDev.apiKeys.expires'.tr(namedArgs: {
                                  'date':
                                      '${exp.day}.${exp.month}.${exp.year}'
                                }),
                                style: AppTypography.label(
                                    size: 9,
                                    color: expired
                                        ? AppColors.herzrotWarm
                                        : AppColors.lightMute),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'common.edit'.tr(),
                        onPressed: () => onEdit(k),
                        icon: const Icon(LucideIcons.pencil,
                            size: 14, color: AppColors.bronze),
                      ),
                      IconButton(
                        tooltip: 'common.delete'.tr(),
                        onPressed: () => onDelete(service),
                        icon: const Icon(LucideIcons.trash2,
                            size: 14, color: AppColors.herzrotWarm),
                      ),
                    ],
                  ),
                );
              }),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: Text('adminDev.apiKeys.add'.tr()),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.teal),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Auto-Changelog: gemergte Godmode-Änderungen (Klapp-Karte).
class _ChangelogCard extends StatelessWidget {
  const _ChangelogCard({
    required this.entries,
    required this.expanded,
    required this.onToggle,
  });
  final List<Map<String, dynamic>> entries;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(LucideIcons.history,
                      size: 16, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('adminDev.changelog.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.lightInk,
                            weight: FontWeight.w700)),
                  ),
                  if (entries.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('${entries.length}',
                          style: AppTypography.label(
                              size: 10, color: AppColors.lightMute)),
                    ),
                  Icon(
                      expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.lightMute),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('adminDev.changelog.empty'.tr(),
                    style: AppTypography.caption()),
              )
            else
              ...entries.take(50).map((e) {
                final title = e['title'] as String? ?? '';
                final pr = e['pr_number'];
                final summary = (e['summary'] as String?)?.trim() ?? '';
                final loc = (e['location'] as String?)?.trim() ?? '';
                final showLoc = loc.isNotEmpty &&
                    !loc.toLowerCase().startsWith('nicht sichtbar');
                final files = (e['files'] as List?)
                        ?.map((f) => f.toString())
                        .toList() ??
                    const <String>[];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(13, 8, 13, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.gitMerge,
                              size: 13, color: AppColors.leben),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pr != null ? '$title  (#$pr)' : title,
                              style: AppTypography.body(
                                  size: 12,
                                  color: AppColors.lightInk,
                                  weight: FontWeight.w600),
                            ),
                          ),
                          if (files.isNotEmpty)
                            Text(
                              'adminDev.changelog.fileCount'
                                  .tr(namedArgs: {'n': '${files.length}'}),
                              style: AppTypography.label(
                                  size: 9, color: AppColors.lightMute),
                            ),
                        ],
                      ),
                      if (summary.isNotEmpty &&
                          summary.toLowerCase() != title.toLowerCase()) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 21),
                          child: SizedBox(height: 2),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 21),
                          child: Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(
                                color: AppColors.lightMute),
                          ),
                        ),
                      ],
                      if (showLoc) ...[
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.only(left: 21),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(LucideIcons.mapPin,
                                  size: 11, color: AppColors.teal),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  loc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(
                                      color: AppColors.teal),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (files.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 21),
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: files.take(6).map((f) {
                              final name = f.split('/').last;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.lightRaised,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(name,
                                    style: AppTypography.label(
                                        size: 9, color: AppColors.lightMute)),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

/// Post-Merge-Gesundheitswächter: zeigt offene Crash-Anstieg-Alarme nach einem
/// Godmode-Merge. SICHERER ALARM — der Wächter rollt NICHTS automatisch zurück;
/// der Admin entscheidet (quittieren, als erledigt markieren oder Fix-Auftrag).
class _HealthAlertsCard extends StatelessWidget {
  const _HealthAlertsCard({
    required this.alerts,
    required this.busyIds,
    required this.onAcknowledge,
    required this.onResolve,
    required this.onFix,
  });
  final List<Map<String, dynamic>> alerts;
  final Set<String> busyIds;
  final ValueChanged<String> onAcknowledge;
  final ValueChanged<String> onResolve;
  final ValueChanged<Map<String, dynamic>> onFix;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.herzrot.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.herzrot.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 6),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 16, color: AppColors.herzrot),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('adminDev.healthAlert.title'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.herzrot,
                          weight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.herzrot,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${alerts.length}',
                      style: AppTypography.label(
                          size: 10, color: Colors.white)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
            child: Text('adminDev.healthAlert.subtitle'.tr(),
                style: AppTypography.caption(color: AppColors.lightMute)),
          ),
          ...alerts.map((a) {
            final id = a['id'] as String;
            final busy = busyIds.contains(id);
            final pr = a['pr_number'];
            final mergeTitle = a['merge_title'] as String? ?? '';
            final msg = (a['error_message'] as String? ?? '').trim();
            final etype = a['error_type'] as String? ?? '';
            final crashes = a['crash_count'] ?? 0;
            final users = a['affected_users'] ?? 0;
            return Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.lightLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'adminDev.healthAlert.spike'.tr(namedArgs: {
                      'crashes': '$crashes',
                      'users': '$users',
                    }),
                    style: AppTypography.body(
                        size: 12,
                        color: AppColors.herzrot,
                        weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    etype.isEmpty ? msg : '$etype: $msg',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                        size: 11, color: AppColors.lightInk),
                  ),
                  if (mergeTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pr != null
                          ? '$mergeTitle  (#$pr)'
                          : mergeTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                          color: AppColors.lightMute),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _AlertAction(
                          icon: LucideIcons.wrench,
                          label: 'adminDev.healthAlert.fix'.tr(),
                          primary: true,
                          onTap: () => onFix(a),
                        ),
                        _AlertAction(
                          icon: LucideIcons.check,
                          label: 'adminDev.healthAlert.acknowledge'.tr(),
                          onTap: () => onAcknowledge(id),
                        ),
                        _AlertAction(
                          icon: LucideIcons.checkCheck,
                          label: 'adminDev.healthAlert.resolve'.tr(),
                          onTap: () => onResolve(id),
                        ),
                      ],
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

class _AlertAction extends StatelessWidget {
  const _AlertAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.lightInk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? AppColors.herzrot : AppColors.lightRaised,
          borderRadius: BorderRadius.circular(8),
          border: primary
              ? null
              : Border.all(color: AppColors.lightLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.label(size: 11, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Modul-Health-Matrix: Bewertung jedes App-Moduls aus dem Tiefenscan —
/// schwächste zuerst, damit klar ist, wo Godmode als Nächstes ansetzen sollte.
class _ModuleHealthCard extends StatelessWidget {
  const _ModuleHealthCard({
    required this.modules,
    required this.expanded,
    required this.onToggle,
  });
  final List<Map<String, dynamic>> modules;
  final bool expanded;
  final VoidCallback onToggle;

  Color _scoreColor(int s) {
    if (s >= 75) return AppColors.leben;
    if (s >= 50) return AppColors.amber;
    return AppColors.herzrot;
  }

  @override
  Widget build(BuildContext context) {
    final avg = modules.isEmpty
        ? 0
        : (modules
                    .map((m) => (m['score'] as num?)?.toInt() ?? 0)
                    .reduce((a, b) => a + b) /
                modules.length)
            .round();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(LucideIcons.layoutGrid,
                      size: 16, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('adminDev.moduleHealth.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.lightInk,
                            weight: FontWeight.w700)),
                  ),
                  Text('Ø $avg',
                      style: AppTypography.label(
                          size: 11, color: _scoreColor(avg))),
                  const SizedBox(width: 6),
                  Icon(
                      expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.lightMute),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            ...modules.map((m) {
              final label = m['label'] as String? ?? m['module'] as String? ?? '';
              final score = (m['score'] as num?)?.toInt() ?? 0;
              final comp = (m['completeness'] as num?)?.toInt() ?? 0;
              final qual = (m['quality'] as num?)?.toInt() ?? 0;
              final tests = (m['tests'] as num?)?.toInt() ?? 0;
              final notes = (m['notes'] as String?)?.trim() ?? '';
              final c = _scoreColor(score);
              return Padding(
                padding: const EdgeInsets.fromLTRB(13, 9, 13, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(label,
                              style: AppTypography.body(
                                  size: 12.5,
                                  color: AppColors.lightInk,
                                  weight: FontWeight.w600)),
                        ),
                        Text('$score',
                            style: AppTypography.label(size: 12, color: c)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.lightRaised,
                        valueColor: AlwaysStoppedAnimation(c),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'adminDev.moduleHealth.subscores'.tr(namedArgs: {
                        'comp': '$comp',
                        'qual': '$qual',
                        'tests': '$tests',
                      }),
                      style: AppTypography.label(
                          size: 9, color: AppColors.lightMute),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(
                              color: AppColors.lightMute)),
                    ],
                    const Divider(height: 14),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/// Überwachter Autopilot: Godmode nimmt täglich den Top-Quick-Win und liefert
/// ihn — mit Veto via Review-Gate (CI baut, Merge erst nach Freigabe).
class _AutopilotCard extends StatelessWidget {
  const _AutopilotCard({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.teal.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: enabled
              ? AppColors.teal.withValues(alpha: 0.4)
              : AppColors.lightLine,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      child: Row(
        children: [
          Icon(LucideIcons.activity,
              size: 18,
              color: enabled ? AppColors.teal : AppColors.lightMute),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('adminDev.autopilot.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('adminDev.autopilot.subtitle'.tr(),
                    style: AppTypography.caption(color: AppColors.lightMute)),
              ],
            ),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Switch(
                  value: enabled,
                  onChanged: onChanged,
                  activeColor: AppColors.teal,
                ),
        ],
      ),
    );
  }
}
