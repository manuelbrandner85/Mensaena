import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_moderation_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// KI-Moderations-Queue — zeigt offene Meldungen mit KI-Empfehlung.
/// Admin triggert Batch-Analyse, sieht farbcodierte Empfehlungen und
/// kann per Tap direkt Keep / Remove / Escalate ausführen.
class AdminAiModerationScreen extends ConsumerStatefulWidget {
  const AdminAiModerationScreen({super.key});

  @override
  ConsumerState<AdminAiModerationScreen> createState() =>
      _AdminAiModerationScreenState();
}

class _AdminAiModerationScreenState
    extends ConsumerState<AdminAiModerationScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = false;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await AiModerationRepository.fetchPendingReports();
    if (mounted) setState(() { _reports = rows; _loading = false; });
  }

  Future<void> _analyzeAll() async {
    setState(() => _analyzing = true);
    try {
      final res = await AiModerationRepository.analyzeQueue();
      if (res['reports'] != null) {
        final list = (res['reports'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        if (mounted) setState(() => _reports = list);
      } else if (res['disabled'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('adminModeration.disabled'.tr())));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('adminModeration.analyzeFailed'.tr())));
      }
    }
    if (mounted) setState(() => _analyzing = false);
  }

  Future<void> _action(String reportId, String action) async {
    final ok = await AiModerationRepository.updateReportStatus(reportId, action);
    if (!mounted) return;
    if (ok) {
      setState(() => _reports.removeWhere((r) => r['id'] == reportId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminModeration.actionDone'.tr())));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminModeration.actionFailed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'adminModeration.title'.tr(),
      currentRoute: '/dashboard/admin/moderation',
      onRefresh: _load,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              analyzing: _analyzing,
              onAnalyze: _loading ? null : _analyzeAll,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _reports.isEmpty
                      ? _EmptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _reports.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _ReportCard(
                              report: _reports[i],
                              onAction: _action,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.analyzing, this.onAnalyze});

  final bool analyzing;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.teal.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldAlert, size: 20, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'adminModeration.subtitle'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.lightMute),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: analyzing ? null : onAnalyze,
            icon: analyzing
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.sparkles, size: 14),
            label: Text(analyzing
                ? 'adminModeration.analyzing'.tr()
                : 'adminModeration.analyze'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Report Card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onAction});

  final Map<String, dynamic> report;
  final Future<void> Function(String id, String action) onAction;

  Color get _borderColor {
    switch (report['ai_recommendation']) {
      case 'remove': return Colors.red.shade400;
      case 'escalate': return Colors.orange.shade400;
      case 'keep': return AppColors.leben;
      default: return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = report['ai_recommendation'] as String?;
    final confidence = report['ai_confidence'] as double?;
    final pct = confidence != null ? (confidence * 100).round() : null;
    final reason = report['ai_reason'] as String?;
    final contentType = report['content_type'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _borderColor, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(type: contentType),
                const Spacer(),
                if (rec != null) _RecBadge(rec: rec),
                if (pct != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    'adminModeration.confidence'
                        .tr(namedArgs: {'pct': '$pct'}),
                    style: AppTypography.body(
                        size: 11, color: AppColors.lightMute),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report['reason'] as String? ?? '',
              style: AppTypography.body(
                  size: 13, color: AppColors.lightInk,
                  weight: FontWeight.w500),
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(LucideIcons.sparkles,
                        size: 13, color: AppColors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reason,
                        style: AppTypography.body(
                            size: 12, color: AppColors.lightInk),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionBtn(
                  label: 'adminModeration.actionKeep'.tr(),
                  color: AppColors.leben,
                  icon: LucideIcons.check,
                  onTap: () => onAction(report['id'] as String, 'keep'),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'adminModeration.actionEscalate'.tr(),
                  color: Colors.orange,
                  icon: LucideIcons.arrowUpRight,
                  onTap: () => onAction(report['id'] as String, 'escalate'),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'adminModeration.actionRemove'.tr(),
                  color: Colors.red,
                  icon: LucideIcons.trash2,
                  onTap: () => onAction(report['id'] as String, 'remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final label = 'adminModeration.contentType.$type'.tr();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppTypography.body(
              size: 11,
              color: AppColors.teal,
              weight: FontWeight.w600)),
    );
  }
}

class _RecBadge extends StatelessWidget {
  const _RecBadge({required this.rec});
  final String rec;

  Color get _bg {
    switch (rec) {
      case 'remove': return Colors.red.shade50;
      case 'escalate': return Colors.orange.shade50;
      case 'keep': return AppColors.leben.withValues(alpha: 0.08);
      default: return Colors.grey.shade100;
    }
  }

  Color get _fg {
    switch (rec) {
      case 'remove': return Colors.red.shade700;
      case 'escalate': return Colors.orange.shade700;
      case 'keep': return AppColors.leben;
      default: return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: _bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        'adminModeration.rec.$rec'.tr(),
        style: TextStyle(
            fontSize: 11, color: _fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 6),
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shieldCheck,
              size: 48, color: AppColors.lebenSoft),
          const SizedBox(height: 12),
          Text('adminModeration.empty'.tr(),
              style: AppTypography.body(size: 13, color: AppColors.lightMute)),
        ],
      ),
    );
  }
}
