import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_moderation_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// Krisen-Triage — zeigt aktive Krisen mit KI-Dringlichkeitsbewertung.
/// Admin triggert Batch-Triage, sieht Dringlichkeit + Maßnahmenempfehlungen
/// und kann direkt zur Krise springen.
class AdminAiCrisisScreen extends ConsumerStatefulWidget {
  const AdminAiCrisisScreen({super.key});

  @override
  ConsumerState<AdminAiCrisisScreen> createState() =>
      _AdminAiCrisisScreenState();
}

class _AdminAiCrisisScreenState extends ConsumerState<AdminAiCrisisScreen> {
  List<Map<String, dynamic>> _crises = [];
  bool _loading = false;
  bool _analyzing = false;

  static const _urgencyOrder = ['critical', 'high', 'medium', 'low'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await AiModerationRepository.fetchActiveCrises();
    if (mounted) setState(() { _crises = _sorted(rows); _loading = false; });
  }

  List<Map<String, dynamic>> _sorted(List<Map<String, dynamic>> list) {
    final copy = List<Map<String, dynamic>>.from(list);
    copy.sort((a, b) {
      final ai = _urgencyOrder.indexOf(a['ai_triage_urgency'] as String? ?? '');
      final bi = _urgencyOrder.indexOf(b['ai_triage_urgency'] as String? ?? '');
      final ar = ai == -1 ? _urgencyOrder.length : ai;
      final br = bi == -1 ? _urgencyOrder.length : bi;
      return ar.compareTo(br);
    });
    return copy;
  }

  Future<void> _triageAll() async {
    setState(() => _analyzing = true);
    try {
      final res = await AiModerationRepository.triageCrises();
      if (res['crises'] != null) {
        final list = (res['crises'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        if (mounted) setState(() => _crises = _sorted(list));
      } else if (res['disabled'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('adminCrisis.disabled'.tr())));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('adminCrisis.analyzeFailed'.tr())));
      }
    }
    if (mounted) setState(() => _analyzing = false);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'adminCrisis.title'.tr(),
      currentRoute: '/dashboard/admin/crisis-triage',
      onRefresh: _load,
      body: SafeArea(
        child: Column(
          children: [
            _Header(analyzing: _analyzing, onAnalyze: _loading ? null : _triageAll),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _crises.isEmpty
                      ? _EmptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _crises.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _CrisisCard(crisis: _crises[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.analyzing, this.onAnalyze});
  final bool analyzing;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade50,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Icon(LucideIcons.siren, size: 20, color: Colors.red.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'adminCrisis.subtitle'.tr(),
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
                ? 'adminCrisis.analyzing'.tr()
                : 'adminCrisis.analyze'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Crisis Card ───────────────────────────────────────────────────────────────

class _CrisisCard extends StatelessWidget {
  const _CrisisCard({required this.crisis});
  final Map<String, dynamic> crisis;

  static const _urgencyOrder = ['critical', 'high', 'medium', 'low'];

  Color _urgencyColor(String? u) {
    switch (u) {
      case 'critical': return Colors.red.shade700;
      case 'high':     return Colors.orange.shade700;
      case 'medium':   return Colors.amber.shade700;
      default:         return Colors.green.shade700;
    }
  }

  Color _urgencyBg(String? u) {
    switch (u) {
      case 'critical': return Colors.red.shade50;
      case 'high':     return Colors.orange.shade50;
      case 'medium':   return Colors.amber.shade50;
      default:         return Colors.green.shade50;
    }
  }

  IconData _urgencyIcon(String? u) {
    switch (u) {
      case 'critical': return LucideIcons.alertOctagon;
      case 'high':     return LucideIcons.alertTriangle;
      case 'medium':   return LucideIcons.alertCircle;
      default:         return LucideIcons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiUrgency = crisis['ai_triage_urgency'] as String?;
    final reportedUrgency = crisis['urgency'] as String?;
    final triage = crisis['ai_triage'] as String?;
    final actions = (crisis['ai_triage_actions'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final helpers = crisis['helper_count'] as int? ?? 0;
    final needed = crisis['needed_helpers'] as int? ?? 0;
    final affected = crisis['affected_count'] as int? ?? 0;

    final urgencyHasChanged = aiUrgency != null &&
        reportedUrgency != null &&
        aiUrgency != reportedUrgency &&
        _urgencyOrder.contains(aiUrgency) &&
        _urgencyOrder.contains(reportedUrgency) &&
        _urgencyOrder.indexOf(aiUrgency) <
            _urgencyOrder.indexOf(reportedUrgency);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: BorderSide(color: _urgencyColor(aiUrgency), width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    crisis['title'] as String? ?? '',
                    style: AppTypography.body(
                        size: 13, color: AppColors.lightInk,
                        weight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (aiUrgency != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _urgencyBg(aiUrgency),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_urgencyIcon(aiUrgency),
                            size: 11, color: _urgencyColor(aiUrgency)),
                        const SizedBox(width: 4),
                        Text(
                          'adminCrisis.urgency.$aiUrgency'.tr(),
                          style: TextStyle(
                              fontSize: 11,
                              color: _urgencyColor(aiUrgency),
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                Text(
                  '${crisis['category'] ?? ''}',
                  style: AppTypography.body(
                      size: 11, color: AppColors.lightMute),
                ),
                Text(
                  'adminCrisis.helpers'.tr(namedArgs: {
                    'current': '$helpers',
                    'needed': '$needed'
                  }),
                  style: AppTypography.body(
                      size: 11, color: AppColors.lightMute),
                ),
                Text(
                  'adminCrisis.affected'
                      .tr(namedArgs: {'n': '$affected'}),
                  style: AppTypography.body(
                      size: 11, color: AppColors.lightMute),
                ),
                if (urgencyHasChanged)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.trendingUp,
                          size: 12, color: Colors.red.shade500),
                      const SizedBox(width: 2),
                      Text(
                        '${'adminCrisis.reportedUrgency'.tr()}: '
                        '${'adminCrisis.urgency.$reportedUrgency'.tr()}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.red.shade400),
                      ),
                    ],
                  ),
              ],
            ),
            if (triage != null && triage.isNotEmpty) ...[
              const SizedBox(height: 8),
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
                      child: Text(triage,
                          style: AppTypography.body(
                              size: 12, color: AppColors.lightInk)),
                    ),
                  ],
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('adminCrisis.suggestedActions'.tr(),
                  style: AppTypography.body(
                      size: 11,
                      color: AppColors.lightMute,
                      weight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...actions.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(LucideIcons.chevronRight,
                            size: 13, color: AppColors.teal),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(a,
                              style: AppTypography.body(
                                  size: 12, color: AppColors.lightInk)),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    context.push('/crisis/${crisis['id']}'),
                icon: const Icon(LucideIcons.externalLink, size: 13),
                label: Text('adminCrisis.openCrisis'.tr()),
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.shieldCheck,
              size: 48, color: Colors.green.shade300),
          const SizedBox(height: 12),
          Text('adminCrisis.empty'.tr(),
              style: AppTypography.body(size: 13, color: AppColors.lightMute)),
        ],
      ),
    );
  }
}
