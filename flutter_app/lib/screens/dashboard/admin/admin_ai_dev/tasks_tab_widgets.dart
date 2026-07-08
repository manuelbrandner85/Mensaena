part of '../admin_ai_dev_screen.dart';

// ── Task Card (mit Live-Pipeline) ───────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    this.onDelete,
    this.onCancel,
    this.onMerge,
    this.onShowDiff,
    this.onRetry,
    this.onRollback,
    this.onRefine,
    this.onDetails,
    this.busy = false,
  });
  final Map<String, dynamic> task;
  final VoidCallback? onDelete;
  final VoidCallback? onCancel;
  final VoidCallback? onMerge;
  final VoidCallback? onShowDiff;
  final VoidCallback? onRetry;
  final VoidCallback? onRollback;
  final VoidCallback? onRefine;
  final VoidCallback? onDetails;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String? ?? 'queued';
    final ciStatus = task['ci_status'] as String?;
    final instruction = task['instruction'] as String? ?? '';
    final prUrl = task['pr_url'] as String?;
    final runUrl = task['run_url'] as String?;
    final ciRunUrl = task['ci_run_url'] as String?;
    final summary = task['summary'] as String?;
    final error = task['error'] as String?;
    final location = (task['location'] as String?)?.trim();
    final showLocation = location != null &&
        location.isNotEmpty &&
        !location.toLowerCase().startsWith('nicht sichtbar');
    // Live-Fortschritt (#4): welche Datei der Agent gerade bearbeitet.
    final liveFile = (task['current_file'] as String?)?.trim();
    final liveCount = (task['analyzed_files'] as num?)?.toInt() ?? 0;
    final showLive = status == 'running' && liveFile != null && liveFile.isNotEmpty;
    final imageCount = (task['image_urls'] as List?)?.length ?? 0;
    final meta = _statusMeta(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightLine),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.icon, size: 15, color: meta.color),
              const SizedBox(width: 6),
              Text(
                'adminDev.status.$status'.tr(),
                style: AppTypography.body(
                    size: 12, color: meta.color, weight: FontWeight.w600),
              ),
              if (_modelShortLabel(task['model'] as String?) != null) ...[
                const SizedBox(width: 6),
                _Badge(
                  text: _modelShortLabel(task['model'] as String?)!,
                  color: AppColors.trust,
                ),
              ],
              // Retry-Zähler: sichtbar, sobald der Watchdog den Auftrag
              // mindestens einmal erneut angestoßen hat (max. 3 Versuche).
              if (((task['retry_count'] as num?)?.toInt() ?? 0) > 0) ...[
                const SizedBox(width: 6),
                _Badge(
                  text: 'adminDev.retryBadge'.tr(namedArgs: {
                    'n': '${(task['retry_count'] as num?)?.toInt() ?? 0}',
                  }),
                  color: AppColors.amber,
                ),
              ],
              if (imageCount > 0) ...[
                const SizedBox(width: 6),
                const Icon(LucideIcons.image, size: 12, color: AppColors.lightMute),
                const SizedBox(width: 2),
                Text('$imageCount',
                    style: AppTypography.body(
                        size: 11, color: AppColors.lightMute)),
              ],
              const Spacer(),
              if (_relativeTime(task['updated_at'] as String?) != null) ...[
                Text(
                  _relativeTime(task['updated_at'] as String?)!,
                  style: AppTypography.label(size: 10, color: AppColors.lightMute),
                ),
                const SizedBox(width: 6),
              ],
              if (onDetails != null) ...[
                InkWell(
                  onTap: onDetails,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(LucideIcons.maximize2,
                        size: 14, color: AppColors.lightMute),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (busy)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.lightMute),
                )
              else if (onCancel != null)
                InkWell(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(LucideIcons.x,
                        size: 16, color: AppColors.lightMute),
                  ),
                )
              else if (onDelete != null)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(LucideIcons.trash2,
                        size: 15, color: AppColors.lightMute),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _PipelineStepper(status: status, ciStatus: ciStatus),
          const SizedBox(height: 10),
          Text(
            instruction,
            style: AppTypography.body(size: 13, color: AppColors.lightInk),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          // Multi-Step-Plan als Checkliste (wenn vorhanden). Bei 'merged' gelten
          // alle Schritte als erledigt.
          if (task['plan'] is List && (task['plan'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            ...List.generate((task['plan'] as List).length, (i) {
              final step = (task['plan'] as List)[i].toString();
              final done = status == 'merged' || status == 'live';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      done ? LucideIcons.checkCircle2 : LucideIcons.circle,
                      size: 13,
                      color: done ? AppColors.leben : AppColors.lightMute,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(step,
                          style: AppTypography.body(
                              size: 11, color: AppColors.lightMute)),
                    ),
                  ],
                ),
              );
            }),
          ],
          // Auto-Phasen: Parent zeigt Phasen-Fortschritt, Child zeigt sein
          // Phasen-Badge. (plan ist hier eine Map, nicht die Legacy-List.)
          if (task['plan'] is Map) ...[
            Builder(builder: (_) {
              final p = task['plan'] as Map;
              final phases = p['phases'];
              if (phases is List && phases.isNotEmpty) {
                final total = phases.length;
                final current = (p['current'] as num?)?.toInt() ?? 0;
                final allDone = status == 'merged' || status == 'live';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(total, (i) {
                      final ph = phases[i];
                      final title = (ph is Map ? ph['title'] : null)?.toString() ??
                          'Phase ${i + 1}';
                      final done = allDone || i < current;
                      final active = !allDone && i == current;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              done
                                  ? LucideIcons.checkCircle2
                                  : active
                                      ? LucideIcons.loader
                                      : LucideIcons.circle,
                              size: 13,
                              color: done
                                  ? AppColors.leben
                                  : active
                                      ? AppColors.teal
                                      : AppColors.lightMute,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${'adminDev.phaseOf'.tr(namedArgs: {
                                      'n': '${i + 1}',
                                      'total': '$total',
                                    })} · $title',
                                style: AppTypography.body(
                                    size: 11,
                                    color: active
                                        ? AppColors.lightInk
                                        : AppColors.lightMute),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                );
              }
              final idx = (p['phase_index'] as num?)?.toInt();
              final ptot = (p['phase_total'] as num?)?.toInt();
              if (idx != null && ptot != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.layers,
                          size: 12, color: AppColors.teal),
                      const SizedBox(width: 5),
                      Text(
                        'adminDev.phaseOf'.tr(
                            namedArgs: {'n': '${idx + 1}', 'total': '$ptot'}),
                        style: AppTypography.body(
                            size: 11,
                            color: AppColors.teal,
                            weight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
          // Fundort: WO in der App die Änderung sichtbar ist (aus dem
          // "📍 Zu finden:"-Pflichtblock des Agent-PRs extrahiert).
          if (showLocation) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.mapPin,
                    size: 12, color: AppColors.teal),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${'adminDev.location'.tr()}: $location',
                    style: AppTypography.body(
                        size: 11,
                        color: AppColors.teal,
                        weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          // Live-Fortschritt (#4): pulsierende Datei-Anzeige während der Agent
          // arbeitet — der Tailer schreibt current_file/analyzed_files laufend.
          if (showLive) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(LucideIcons.fileEdit, size: 12, color: AppColors.amber),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    liveCount > 0 ? '$liveFile  ·  $liveCount' : '$liveFile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                        size: 11, color: AppColors.amber, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(summary,
                style:
                    AppTypography.body(size: 11, color: AppColors.lightMute)),
          ],
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(error,
                style:
                    AppTypography.body(size: 11, color: Colors.red.shade600)),
          ],
          if (prUrl != null || runUrl != null || ciRunUrl != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (prUrl != null)
                  _LinkButton(
                    icon: LucideIcons.gitPullRequest,
                    label: 'adminDev.openPr'.tr(),
                    url: prUrl,
                  ),
                if (ciRunUrl != null)
                  _LinkButton(
                    icon: LucideIcons.checkCircle2,
                    label: 'adminDev.stage.ci'.tr(),
                    url: ciRunUrl,
                  ),
                if (runUrl != null)
                  _LinkButton(
                    icon: LucideIcons.terminal,
                    label: 'adminDev.openRun'.tr(),
                    url: runUrl,
                  ),
              ],
            ),
          ],
          // Wiederholen-Button für fehlgeschlagene Aufträge.
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: Text('adminDev.retry'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: BorderSide(color: AppColors.teal.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
          // Ein-Tap-Rollback für gemergte Änderungen.
          if (onRollback != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRollback,
                icon: const Icon(LucideIcons.rotateCcw, size: 14),
                label: Text('adminDev.rollback.button'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
          // Diff-Vorschau + (bei Review-Gate) manuelle Freigabe.
          if (onShowDiff != null || onMerge != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onShowDiff != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onShowDiff,
                    icon: const Icon(LucideIcons.fileSearch, size: 14),
                    label: Text('adminDev.viewDiff'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: BorderSide(
                          color: AppColors.teal.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (onMerge != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onMerge,
                      icon: busy
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.checkCircle2, size: 15),
                      label: Text('adminDev.approveMerge'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (onRefine != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRefine,
                icon: const Icon(LucideIcons.messageSquarePlus, size: 14),
                label: Text('adminDev.refine.button'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.bronze,
                  side: BorderSide(
                      color: AppColors.bronze.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StatusMeta _statusMeta(String status) {
    switch (status) {
      case 'live':
        return const _StatusMeta(LucideIcons.radio, AppColors.leben);
      case 'merged':
        return const _StatusMeta(LucideIcons.checkCircle2, AppColors.leben);
      case 'phased':
        return const _StatusMeta(LucideIcons.layers, AppColors.teal);
      case 'pr_open':
        return const _StatusMeta(LucideIcons.gitPullRequest, AppColors.teal);
      case 'awaiting_review':
        return const _StatusMeta(LucideIcons.eye, AppColors.amber);
      case 'running':
        return const _StatusMeta(LucideIcons.loader, AppColors.amber);
      case 'error_retry':
        return const _StatusMeta(LucideIcons.rotateCw, AppColors.amber);
      case 'failed':
        return const _StatusMeta(LucideIcons.xCircle, Colors.red);
      case 'patch_failed':
        return const _StatusMeta(LucideIcons.alertTriangle, Colors.red);
      case 'cancelled':
        return const _StatusMeta(LucideIcons.ban, AppColors.lightMute);
      case 'already_done':
        // Bereits umgesetzt = Erfolg, kein Fehler → grünes Häkchen.
        return const _StatusMeta(LucideIcons.checkCheck, AppColors.leben);
      case 'no_changes':
        return const _StatusMeta(LucideIcons.minusCircle, AppColors.lightMute);
      default:
        return const _StatusMeta(LucideIcons.clock, AppColors.lightMute);
    }
  }
}

class _StatusMeta {
  const _StatusMeta(this.icon, this.color);
  final IconData icon;
  final Color color;
}

// ── Pipeline-Stepper: Agent → PR → CI → Merge → OTA ─────────────────────────

enum _Stage { done, active, pending, error }

/// Detailansicht eines Auftrags — alle Infos auf einen Blick (Instruction,
/// Pipeline, Plan, Modell, PR/CI-Links, Zusammenfassung, vollständiges
/// Fehler-Log, Zeitstempel). Öffnet sich beim Tippen auf das Detail-Icon.
class _TaskDetailSheet extends StatelessWidget {
  const _TaskDetailSheet({required this.task});
  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String? ?? 'queued';
    final ciStatus = task['ci_status'] as String?;
    final instruction = task['instruction'] as String? ?? '';
    final summary = task['summary'] as String?;
    final location = (task['location'] as String?)?.trim();
    final error = task['error'] as String?;
    final prUrl = task['pr_url'] as String?;
    final runUrl = task['run_url'] as String?;
    final ciRunUrl = task['ci_run_url'] as String?;
    final model = _modelShortLabel(task['model'] as String?);
    final created = _relativeTime(task['created_at'] as String?);
    final updated = _relativeTime(task['updated_at'] as String?);
    final prNumber = task['pr_number'];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('adminDev.detail.title'.tr(),
                    style: AppTypography.body(
                        size: 15,
                        color: AppColors.lightInk,
                        weight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 18),
                  color: AppColors.lightMute,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Badge(text: 'adminDev.status.$status'.tr(), color: AppColors.teal),
                if (model != null) _Badge(text: model, color: AppColors.trust),
                if (prNumber != null)
                  _Badge(text: '#$prNumber', color: AppColors.lightMute),
              ],
            ),
            const SizedBox(height: 12),
            _PipelineStepper(status: status, ciStatus: ciStatus),
            const SizedBox(height: 14),
            _detailLabel('adminDev.detail.instruction'.tr()),
            const SizedBox(height: 4),
            SelectableText(
              instruction,
              style: AppTypography.body(size: 13, color: AppColors.lightInk),
            ),
            if (location != null &&
                location.isNotEmpty &&
                !location.toLowerCase().startsWith('nicht sichtbar')) ...[
              const SizedBox(height: 14),
              _detailLabel('adminDev.location'.tr()),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.mapPin,
                      size: 13, color: AppColors.teal),
                  const SizedBox(width: 5),
                  Expanded(
                    child: SelectableText(location,
                        style: AppTypography.body(
                            size: 12,
                            color: AppColors.teal,
                            weight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailLabel('adminDev.detail.summary'.tr()),
              const SizedBox(height: 4),
              SelectableText(summary,
                  style: AppTypography.body(
                      size: 12, color: AppColors.lightMute)),
            ],
            if (error != null && error.isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailLabel('adminDev.detail.errorLog'.tr()),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: SelectableText(
                  error,
                  style: AppTypography.body(
                      size: 11, color: Colors.red.shade700),
                ),
              ),
            ],
            if (prUrl != null || ciRunUrl != null || runUrl != null) ...[
              const SizedBox(height: 14),
              _detailLabel('adminDev.detail.links'.tr()),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (prUrl != null)
                    _LinkButton(
                        icon: LucideIcons.gitPullRequest,
                        label: 'adminDev.openPr'.tr(),
                        url: prUrl),
                  if (ciRunUrl != null)
                    _LinkButton(
                        icon: LucideIcons.checkCircle2,
                        label: 'adminDev.stage.ci'.tr(),
                        url: ciRunUrl),
                  if (runUrl != null)
                    _LinkButton(
                        icon: LucideIcons.terminal,
                        label: 'adminDev.openRun'.tr(),
                        url: runUrl),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (created != null)
                  Text('adminDev.detail.created'.tr(namedArgs: {'t': created}),
                      style: AppTypography.label(
                          size: 10, color: AppColors.lightMute)),
                if (created != null && updated != null)
                  Text('  ·  ',
                      style: AppTypography.label(
                          size: 10, color: AppColors.lightMute)),
                if (updated != null)
                  Text('adminDev.detail.updated'.tr(namedArgs: {'t': updated}),
                      style: AppTypography.label(
                          size: 10, color: AppColors.lightMute)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLabel(String text) => Text(
        text.toUpperCase(),
        style: AppTypography.label(size: 9, color: AppColors.lightMute),
      );
}

class _PipelineStepper extends StatelessWidget {
  const _PipelineStepper({required this.status, required this.ciStatus});
  final String status;
  final String? ciStatus;

  List<_Stage> _stages() {
    final s = List<_Stage>.filled(5, _Stage.pending);
    switch (status) {
      case 'queued':
      case 'running':
        s[0] = _Stage.active;
        break;
      case 'no_changes':
      case 'already_done':
        s[0] = _Stage.done;
        break;
      case 'pr_open':
        s[0] = _Stage.done;
        s[1] = _Stage.done;
        if (ciStatus == 'success') {
          s[2] = _Stage.done;
          s[3] = _Stage.active;
        } else if (ciStatus == 'failure') {
          s[2] = _Stage.error;
        } else {
          s[2] = _Stage.active; // pending/running
        }
        break;
      case 'awaiting_review':
        // CI grün, wartet auf manuelle Freigabe (Merge-Schritt aktiv).
        s[0] = _Stage.done;
        s[1] = _Stage.done;
        s[2] = _Stage.done;
        s[3] = _Stage.active;
        break;
      case 'merged':
        s[0] = _Stage.done;
        s[1] = _Stage.done;
        s[2] = _Stage.done;
        s[3] = _Stage.done;
        s[4] = _Stage.active; // OTA läuft
        break;
      case 'live':
        // Live-Verify hat die Auslieferung bestätigt → Pipeline komplett.
        for (var i = 0; i < 5; i++) {
          s[i] = _Stage.done;
        }
        break;
      case 'patch_failed':
        // Merge ok, aber der OTA-Patch-Run war rot.
        s[0] = _Stage.done;
        s[1] = _Stage.done;
        s[2] = _Stage.done;
        s[3] = _Stage.done;
        s[4] = _Stage.error;
        break;
      case 'error_retry':
        // Agent-API-Fehler — der Watchdog wiederholt automatisch.
        s[0] = _Stage.active;
        break;
      case 'failed':
        s[0] = _Stage.error;
        break;
      case 'cancelled':
        s[0] = _Stage.error;
        break;
      default:
        s[0] = _Stage.active;
    }
    return s;
  }

  Color _color(_Stage st) {
    switch (st) {
      case _Stage.done:
        return AppColors.teal;
      case _Stage.active:
        return AppColors.amber;
      case _Stage.error:
        return Colors.red.shade600;
      case _Stage.pending:
        return AppColors.lightGhost;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages();
    const labels = [
      'adminDev.stage.agent',
      'adminDev.stage.pr',
      'adminDev.stage.ci',
      'adminDev.stage.merge',
      'adminDev.stage.ota',
    ];
    return Row(
      children: List.generate(5, (i) {
        final st = stages[i];
        final c = _color(st);
        final dot = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: st == _Stage.pending ? Colors.transparent : c.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: c, width: 1.5),
              ),
              child: Icon(
                st == _Stage.done
                    ? LucideIcons.check
                    : st == _Stage.error
                        ? LucideIcons.x
                        : st == _Stage.active
                            ? LucideIcons.loader
                            : LucideIcons.circle,
                size: 9,
                color: c,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              labels[i].tr(),
              style: AppTypography.body(
                size: 8,
                color: st == _Stage.pending ? AppColors.lightMute : c,
                weight: st == _Stage.pending ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        );
        if (i == 4) return dot;
        return Expanded(
          child: Row(
            children: [
              dot,
              Expanded(
                child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 14, left: 2, right: 2),
                  color: stages[i + 1] == _Stage.pending
                      ? AppColors.lightGhost
                      : AppColors.teal.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton(
      {required this.icon, required this.label, required this.url});
  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => safeLaunch(url, context: context),
      icon: Icon(icon, size: 13),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.teal,
        side: BorderSide(color: AppColors.teal.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(0, 32),
      ),
    );
  }
}
