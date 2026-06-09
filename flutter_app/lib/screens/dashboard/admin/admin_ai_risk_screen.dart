import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_insights_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// KI-Risikoprofil — zeigt Nutzer mit erhöhtem Risiko-Score.
/// Score 0–100, Level low/medium/high. Signale: Meldungen, Report-Spam.
class AdminAiRiskScreen extends ConsumerStatefulWidget {
  const AdminAiRiskScreen({super.key});

  @override
  ConsumerState<AdminAiRiskScreen> createState() => _AdminAiRiskScreenState();
}

class _AdminAiRiskScreenState extends ConsumerState<AdminAiRiskScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = false;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await AiInsightsRepository.fetchRiskProfiles();
    if (mounted) setState(() { _profiles = rows; _loading = false; });
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    try {
      final res = await AiInsightsRepository.analyzeRisks();
      if (res['profiles'] != null) {
        final list = (res['profiles'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        if (mounted) setState(() => _profiles = list);
      } else if (res['disabled'] == true) {
        if (mounted) _snack('adminRisk.disabled'.tr());
      }
    } catch (_) {
      if (mounted) _snack('adminRisk.analyzeFailed'.tr());
    }
    if (mounted) setState(() => _analyzing = false);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'adminRisk.title'.tr(),
      currentRoute: '/dashboard/admin/risk',
      onRefresh: _load,
      body: SafeArea(
        child: Column(
          children: [
            _Header(analyzing: _analyzing, onAnalyze: _loading ? null : _analyze),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _profiles.isEmpty
                      ? _EmptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _profiles.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _RiskCard(profile: _profiles[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.analyzing, this.onAnalyze});
  final bool analyzing;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Icon(LucideIcons.shieldOff, size: 20, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text('adminRisk.subtitle'.tr(),
                style: AppTypography.body(size: 12, color: AppColors.lightMute)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: analyzing ? null : onAnalyze,
            icon: analyzing
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.sparkles, size: 14),
            label: Text(analyzing
                ? 'adminRisk.analyzing'.tr()
                : 'adminRisk.analyze'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.profile});
  final Map<String, dynamic> profile;

  Color _levelColor(String level) {
    switch (level) {
      case 'high': return Colors.red.shade600;
      case 'medium': return Colors.orange.shade600;
      default: return AppColors.leben;
    }
  }

  Color _levelBg(String level) {
    switch (level) {
      case 'high': return Colors.red.shade50;
      case 'medium': return Colors.orange.shade50;
      default: return AppColors.leben.withValues(alpha: 0.08);
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = profile['level'] as String? ?? 'low';
    final score = profile['risk_score'] as int? ?? 0;
    final signals = profile['signals'] as Map? ?? {};
    final reason = signals['reason'] as String?;
    final reportsReceived = signals['reports_received'] as int? ?? 0;
    final reportsSubmitted = signals['reports_submitted'] as int? ?? 0;
    final displayName = (profile['profiles'] as Map?)?['display_name']
        as String? ?? profile['display_name'] as String? ?? '—';
    final userId = profile['user_id'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _levelColor(level), width: 4)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _levelBg(level),
                  child: Icon(LucideIcons.user,
                      size: 16, color: _levelColor(level)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: AppTypography.body(
                              size: 13, color: AppColors.lightInk,
                              weight: FontWeight.w600)),
                      Text(
                        'adminRisk.score'.tr(namedArgs: {'score': '$score'}),
                        style: AppTypography.body(
                            size: 11, color: AppColors.lightMute),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _levelBg(level),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'adminRisk.level.$level'.tr(),
                    style: TextStyle(fontSize: 11, color: _levelColor(level),
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Score-Balken
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(_levelColor(level)),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _SignalChip(
                  icon: LucideIcons.flag,
                  label: '$reportsReceived',
                  tooltip: 'adminRisk.reportsReceived'.tr(),
                ),
                _SignalChip(
                  icon: LucideIcons.alertTriangle,
                  label: '$reportsSubmitted',
                  tooltip: 'adminRisk.reportsSubmitted'.tr(),
                ),
              ],
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.sparkles, size: 13, color: AppColors.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(reason,
                        style: AppTypography.body(
                            size: 12, color: AppColors.lightInkSoft)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/dashboard/admin/users/$userId'),
                icon: const Icon(LucideIcons.externalLink, size: 13),
                label: Text('adminRisk.openUser'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.icon, required this.label, required this.tooltip});
  final IconData icon;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppColors.lightMute),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.body(size: 11, color: AppColors.lightMute)),
          ],
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
          Icon(LucideIcons.shieldCheck, size: 48, color: AppColors.lebenSoft),
          const SizedBox(height: 12),
          Text('adminRisk.empty'.tr(),
              style: AppTypography.body(size: 13, color: AppColors.lightMute)),
        ],
      ),
    );
  }
}
