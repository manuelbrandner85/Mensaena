import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_insights_repository.dart';
import '../../../utils/safe_launch.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// Admin-Entwicklungs-Agent — der Admin beschreibt in natürlicher Sprache,
/// was an der App geändert werden soll (Feature, Bugfix, UI/UX, Konfiguration).
/// Der Auftrag triggert eine GitHub Action, die den Code via Claude Code CLI
/// ändert, einen PR erstellt und – NUR bei grünem Flutter-CI – automatisch
/// mergt. Danach liefert Shorebird die Änderung als OTA-Patch an die App.
class AdminAiDevScreen extends ConsumerStatefulWidget {
  const AdminAiDevScreen({super.key});

  @override
  ConsumerState<AdminAiDevScreen> createState() => _AdminAiDevScreenState();
}

class _AdminAiDevScreenState extends ConsumerState<AdminAiDevScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _tasks = const [];
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  static const _suggestions = [
    'adminDev.sug1',
    'adminDev.sug2',
    'adminDev.sug3',
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
    // Solange Tasks laufen, alle 8s aktualisieren.
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_hasActive) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _poll?.cancel();
    super.dispose();
  }

  bool get _hasActive => _tasks.any((t) {
        final s = t['status'] as String?;
        return s == 'queued' || s == 'running' || s == 'pr_open';
      });

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final rows = await AiInsightsRepository.fetchDevTasks();
    if (!mounted) return;
    setState(() {
      _tasks = rows;
      _loading = false;
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    final res = await AiInsightsRepository.createDevTask(text);
    if (!mounted) return;

    final error = res['error'] as String?;
    final ok = res['ok'] == true;
    setState(() => _sending = false);

    if (ok) {
      _ctrl.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminDev.queued'.tr())),
      );
      await _refresh(silent: true);
    } else {
      final key = error == null
          ? 'adminDev.failed'
          : error.contains('not_configured')
              ? 'adminDev.notConfigured'
              : 'adminDev.failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(key.tr()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'adminDev.title'.tr(),
      currentRoute: '/dashboard/admin/dev-agent',
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.teal,
                onRefresh: _refresh,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        children: [
                          if (_tasks.isEmpty) _Suggestions(onTap: _send),
                          ..._tasks.map((t) => _TaskCard(task: t)),
                          const SizedBox(height: 12),
                        ],
                      ),
              ),
            ),
            _InputBar(ctrl: _ctrl, sending: _sending, onSend: _send),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.teal.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Icon(LucideIcons.bot, size: 18, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text('adminDev.subtitle'.tr(),
                style: AppTypography.body(size: 12, color: AppColors.lightMute)),
          ),
        ],
      ),
    );
  }
}

// ── Suggestions ───────────────────────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(LucideIcons.sparkles, size: 40, color: AppColors.teal),
          const SizedBox(height: 12),
          Text('adminDev.empty'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(size: 13, color: AppColors.lightMute)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _AdminAiDevScreenState._suggestions.map((key) {
              final label = key.tr();
              return ActionChip(
                label: Text(label, style: AppTypography.body(size: 12)),
                onPressed: () => onTap(label),
                backgroundColor: AppColors.teal.withValues(alpha: 0.08),
                side: BorderSide(color: AppColors.teal.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Task Card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});
  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String? ?? 'queued';
    final instruction = task['instruction'] as String? ?? '';
    final prUrl = task['pr_url'] as String?;
    final runUrl = task['run_url'] as String?;
    final summary = task['summary'] as String?;
    final error = task['error'] as String?;
    final meta = _statusMeta(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: meta.color, width: 3)),
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
              Icon(meta.icon, size: 16, color: meta.color),
              const SizedBox(width: 6),
              Text('adminDev.status.$status'.tr(),
                  style: AppTypography.body(
                      size: 12, color: meta.color, weight: FontWeight.w600)),
              const Spacer(),
              if (status == 'queued' ||
                  status == 'running' ||
                  status == 'pr_open')
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.teal),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(instruction,
              style: AppTypography.body(size: 13, color: AppColors.lightInk),
              maxLines: 4,
              overflow: TextOverflow.ellipsis),
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(summary,
                style:
                    AppTypography.body(size: 11, color: AppColors.lightMute)),
          ],
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(error,
                style: AppTypography.body(size: 11, color: Colors.red.shade600)),
          ],
          if (prUrl != null || runUrl != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (prUrl != null)
                  _LinkButton(
                    icon: LucideIcons.gitPullRequest,
                    label: 'adminDev.openPr'.tr(),
                    url: prUrl,
                  ),
                if (runUrl != null) ...[
                  const SizedBox(width: 8),
                  _LinkButton(
                    icon: LucideIcons.terminal,
                    label: 'adminDev.openRun'.tr(),
                    url: runUrl,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  _StatusMeta _statusMeta(String status) {
    switch (status) {
      case 'merged':
        return _StatusMeta(LucideIcons.checkCircle2, Colors.green.shade600);
      case 'pr_open':
        return _StatusMeta(LucideIcons.gitPullRequest, AppColors.teal);
      case 'running':
        return _StatusMeta(LucideIcons.loader, AppColors.amber);
      case 'failed':
        return _StatusMeta(LucideIcons.xCircle, Colors.red.shade600);
      case 'no_changes':
        return _StatusMeta(LucideIcons.minusCircle, AppColors.lightMute);
      default: // queued
        return _StatusMeta(LucideIcons.clock, AppColors.lightMute);
    }
  }
}

class _StatusMeta {
  const _StatusMeta(this.icon, this.color);
  final IconData icon;
  final Color color;
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

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar(
      {required this.ctrl, required this.sending, required this.onSend});
  final TextEditingController ctrl;
  final bool sending;
  final Future<void> Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              enabled: !sending,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'adminDev.placeholder'.tr(),
                hintStyle:
                    AppTypography.body(size: 13, color: AppColors.lightMute),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: sending ? null : () => onSend(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.send, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
