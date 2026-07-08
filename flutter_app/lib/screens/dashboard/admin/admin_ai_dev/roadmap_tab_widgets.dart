part of '../admin_ai_dev_screen.dart';

/// Roadmap / Epics: thematische Initiativen mit Fortschritt. Bündelt Aufträge
/// & Vorschläge zu größeren Vorhaben und zeigt den Liefer-Fortschritt.
class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({
    required this.epics,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onNewTask,
    required this.colorOf,
  });
  final List<Map<String, dynamic>> epics;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<String> onDelete;
  final ValueChanged<Map<String, dynamic>> onNewTask;
  final Color Function(String) colorOf;

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
                  const Icon(LucideIcons.map,
                      size: 16, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('adminDev.roadmap.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.lightInk,
                            weight: FontWeight.w700)),
                  ),
                  if (epics.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('${epics.length}',
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
            if (epics.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('adminDev.roadmap.empty'.tr(),
                    style: AppTypography.caption()),
              )
            else
              ...epics.map((e) => _epicTile(context, e)),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 4, 13, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(LucideIcons.plus, size: 15),
                  label: Text('adminDev.roadmap.add'.tr()),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.teal),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _epicTile(BuildContext context, Map<String, dynamic> e) {
    final id = e['id'] as String;
    final title = e['title'] as String? ?? '';
    final desc = e['description'] as String? ?? '';
    final color = colorOf(e['color'] as String? ?? 'teal');
    final status = e['status'] as String? ?? 'active';
    final total = (e['total_tasks'] as num?)?.toInt() ?? 0;
    final done = (e['done_tasks'] as num?)?.toInt() ?? 0;
    final pending = (e['pending_suggestions'] as num?)?.toInt() ?? 0;
    final progress = total > 0 ? done / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(title,
                    style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.lightInk,
                        weight: FontWeight.w700)),
              ),
              if (status == 'done')
                const Icon(LucideIcons.checkCheck,
                    size: 14, color: AppColors.leben)
              else if (status == 'archived')
                const Icon(LucideIcons.archive,
                    size: 14, color: AppColors.lightMute),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onNewTask(e),
                icon: const Icon(LucideIcons.plus, size: 15),
                color: AppColors.teal,
                tooltip: 'adminDev.roadmap.addTaskTooltip'.tr(),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onEdit(e),
                icon: const Icon(LucideIcons.pencil, size: 14),
                color: AppColors.lightMute,
                tooltip: 'common.edit'.tr(),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onDelete(id),
                icon: const Icon(LucideIcons.trash2, size: 14),
                color: AppColors.lightMute,
                tooltip: 'common.delete'.tr(),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(color: AppColors.lightMute)),
          ],
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.lightRaised,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'adminDev.roadmap.progress'.tr(namedArgs: {
              'done': '$done',
              'total': '$total',
              'pending': '$pending',
            }),
            style: AppTypography.label(size: 10, color: AppColors.lightMute),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.metrics,
    required this.expanded,
    required this.onToggle,
  });
  final Map<String, dynamic> metrics;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final total = (metrics['total'] as num?)?.toInt() ?? 0;
    final merged = (metrics['merged'] as num?)?.toInt() ?? 0;
    final failed = (metrics['failed'] as num?)?.toInt() ?? 0;
    final active = (metrics['active'] as num?)?.toInt() ?? 0;
    final rate = (metrics['success_rate'] as num?)?.toInt() ?? 0;
    final avgMin = (metrics['avg_merge_minutes'] as num?)?.toInt() ?? 0;
    final accepted = (metrics['suggestions_accepted'] as num?)?.toInt() ?? 0;
    final rejected = (metrics['suggestions_rejected'] as num?)?.toInt() ?? 0;

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
                  const Icon(LucideIcons.activity,
                      size: 18, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Text(
                    'adminDev.health.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  // Erfolgsquote als kompakter Badge immer sichtbar.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$rate%',
                        style: AppTypography.body(
                            size: 11,
                            color: AppColors.teal,
                            weight: FontWeight.w700)),
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
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _stat('adminDev.health.total'.tr(), '$total',
                      LucideIcons.gitPullRequest),
                  _stat('adminDev.health.merged'.tr(), '$merged',
                      LucideIcons.checkCircle2, color: AppColors.leben),
                  _stat('adminDev.health.active'.tr(), '$active',
                      LucideIcons.loader, color: AppColors.amber),
                  _stat('adminDev.health.failed'.tr(), '$failed',
                      LucideIcons.xCircle, color: Colors.red.shade600),
                  _stat('adminDev.health.successRate'.tr(), '$rate%',
                      LucideIcons.trendingUp, color: AppColors.teal),
                  _stat('adminDev.health.avgMerge'.tr(),
                      avgMin > 0 ? '$avgMin min' : '—', LucideIcons.clock),
                  _stat('adminDev.health.accepted'.tr(), '$accepted',
                      LucideIcons.checkCheck, color: AppColors.leben),
                  _stat('adminDev.health.rejected'.tr(), '$rejected',
                      LucideIcons.x, color: AppColors.lightMute),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, {Color? color}) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.lightMute),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.body(
                  size: 15,
                  color: AppColors.lightInk,
                  weight: FontWeight.w700)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(size: 10, color: AppColors.lightMute)),
        ],
      ),
    );
  }
}

// ── Wiederkehrende Aufträge ──────────────────────────────────────────────────

class _SchedulesCard extends StatelessWidget {
  const _SchedulesCard({
    required this.schedules,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleEnabled,
    required this.onDelete,
  });
  final List<Map<String, dynamic>> schedules;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String, bool) onToggleEnabled;
  final void Function(String) onDelete;

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
                  const Icon(LucideIcons.repeat,
                      size: 18, color: AppColors.trust),
                  const SizedBox(width: 10),
                  Text(
                    'adminDev.schedules.title'.tr(),
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
                    child: Text('${schedules.length}',
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
            if (schedules.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text('adminDev.schedules.empty'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.lightMute)),
              )
            else
              ...schedules.map((s) => _ScheduleTile(
                    schedule: s,
                    onEdit: () => onEdit(s),
                    onDelete: () => onDelete(s['id'] as String),
                    onToggleEnabled: (v) =>
                        onToggleEnabled(s['id'] as String, v),
                  )),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text('adminDev.schedules.add'.tr()),
                style: TextButton.styleFrom(foregroundColor: AppColors.teal),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
  });
  final Map<String, dynamic> schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool) onToggleEnabled;

  String _cadenceLabel() {
    final c = schedule['cadence'] as String? ?? 'weekly';
    return 'adminDev.schedules.cadence.$c'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final title = schedule['title'] as String? ?? '';
    final enabled = schedule['enabled'] == true;
    final hour = (schedule['hour_utc'] as num?)?.toInt() ?? 6;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.lightElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: enabled,
                  onChanged: onToggleEnabled,
                  activeColor: AppColors.teal,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 11, color: AppColors.lightMute),
              const SizedBox(width: 4),
              Text(
                '${_cadenceLabel()} · ${hour.toString().padLeft(2, '0')}:00 UTC',
                style: AppTypography.body(size: 10, color: AppColors.lightMute),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencil, size: 14),
                color: AppColors.lightMute,
                visualDensity: VisualDensity.compact,
                tooltip: 'common.edit'.tr(),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2, size: 14),
                color: AppColors.lightMute,
                visualDensity: VisualDensity.compact,
                tooltip: 'common.delete'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Bottom-Sheet zum Anlegen/Bearbeiten eines wiederkehrenden Auftrags.
class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _instrCtrl;
  String _cadence = 'weekly';
  int _dayOfWeek = 1;
  int _hourUtc = 6;
  bool _awaitReview = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?['title'] as String? ?? '');
    _instrCtrl =
        TextEditingController(text: e?['instruction'] as String? ?? '');
    _cadence = e?['cadence'] as String? ?? 'weekly';
    _dayOfWeek = (e?['day_of_week'] as num?)?.toInt() ?? 1;
    _hourUtc = (e?['hour_utc'] as num?)?.toInt() ?? 6;
    _awaitReview = e?['await_review'] == true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().length < 2 ||
        _instrCtrl.text.trim().length < 5) {
      return;
    }
    setState(() => _saving = true);
    final res = await AiInsightsRepository.saveDevSchedule(
      id: widget.existing?['id'] as String?,
      title: _titleCtrl.text.trim(),
      instruction: _instrCtrl.text.trim(),
      cadence: _cadence,
      dayOfWeek: _dayOfWeek,
      hourUtc: _hourUtc,
      awaitReview: _awaitReview,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['ok'] == true) {
      Navigator.of(context).pop(true);
    } else {
      AppSnackBar.error(context, 'adminDev.schedules.saveFailed'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.lightLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('adminDev.schedules.add'.tr(),
                style: AppTypography.body(
                    size: 16,
                    color: AppColors.lightInk,
                    weight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'adminDev.schedules.titleField'.tr(),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instrCtrl,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                labelText: 'adminDev.schedules.instructionField'.tr(),
                hintText: 'adminDev.placeholder'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Frequenz-Auswahl.
            Row(
              children: [
                for (final c in const ['daily', 'weekly', 'monthly'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('adminDev.schedules.cadence.$c'.tr(),
                          style: AppTypography.body(
                              size: 11,
                              color: _cadence == c
                                  ? Colors.white
                                  : AppColors.lightInk)),
                      selected: _cadence == c,
                      selectedColor: AppColors.teal,
                      onSelected: (_) => setState(() => _cadence = c),
                    ),
                  ),
              ],
            ),
            if (_cadence == 'weekly') ...[
              const SizedBox(height: 10),
              Text('adminDev.schedules.weekday'.tr(),
                  style:
                      AppTypography.body(size: 11, color: AppColors.lightMute)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 0; d < 7; d++)
                    ChoiceChip(
                      label: Text('adminDev.schedules.weekdays.$d'.tr(),
                          style: AppTypography.body(
                              size: 11,
                              color: _dayOfWeek == d
                                  ? Colors.white
                                  : AppColors.lightInk)),
                      selected: _dayOfWeek == d,
                      selectedColor: AppColors.teal,
                      onSelected: (_) => setState(() => _dayOfWeek = d),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text('adminDev.schedules.hour'.tr(),
                    style: AppTypography.body(
                        size: 11, color: AppColors.lightMute)),
                const SizedBox(width: 10),
                Expanded(
                  child: Slider(
                    value: _hourUtc.toDouble(),
                    min: 0,
                    max: 23,
                    divisions: 23,
                    label: '${_hourUtc.toString().padLeft(2, '0')}:00 UTC',
                    activeColor: AppColors.teal,
                    onChanged: (v) => setState(() => _hourUtc = v.round()),
                  ),
                ),
                Text('${_hourUtc.toString().padLeft(2, '0')}:00',
                    style: AppTypography.body(
                        size: 12, color: AppColors.lightInk)),
              ],
            ),
            _MiniToggle(
              label: 'adminDev.reviewBeforeMerge'.tr(),
              value: _awaitReview,
              onChanged: (v) => setState(() => _awaitReview = v),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('common.save'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
