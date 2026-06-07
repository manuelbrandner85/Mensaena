import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_insights_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// Trend-Erkennung — KI analysiert Themen-Spikes der letzten 24h.
class AdminAiTrendScreen extends ConsumerStatefulWidget {
  const AdminAiTrendScreen({super.key});

  @override
  ConsumerState<AdminAiTrendScreen> createState() => _AdminAiTrendScreenState();
}

class _AdminAiTrendScreenState extends ConsumerState<AdminAiTrendScreen> {
  Map<String, dynamic> _result = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    try {
      final res = await AiInsightsRepository.detectTrends(force: force);
      if (mounted) setState(() => _result = res);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('adminTrend.analyzeFailed'.tr())));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _result['summary'] as String?;
    final trends = (_result['trends'] as List?)
            ?.map((t) => Map<String, dynamic>.from(t as Map))
            .toList() ??
        [];
    final stats = _result['stats'] as Map?;
    final cached = _result['cached'] == true;

    return DashboardScaffold(
      title: 'adminTrend.title'.tr(),
      currentRoute: '/dashboard/admin/trends',
      onRefresh: () => _load(force: false),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _load(force: false),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SummaryCard(
                        summary: summary,
                        stats: stats,
                        cached: cached,
                        onRefresh: () => _load(force: true),
                      ),
                      const SizedBox(height: 16),
                      if (trends.isEmpty)
                        _EmptyState()
                      else ...[
                        Text('adminTrend.trendsTitle'.tr(),
                            style: AppTypography.body(
                                size: 13, color: AppColors.lightMute,
                                weight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ...trends.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TrendCard(trend: t),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.stats,
    required this.cached,
    required this.onRefresh,
  });
  final String? summary;
  final Map? stats;
  final bool cached;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final total24h = stats?['total24h'] as int? ?? 0;
    final total6h  = stats?['total6h']  as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.teal.withValues(alpha: 0.15), AppColors.teal.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trendingUp, color: AppColors.teal, size: 20),
              const SizedBox(width: 8),
              Text('adminTrend.subtitle'.tr(),
                  style: AppTypography.body(size: 13, color: AppColors.teal,
                      weight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(LucideIcons.refreshCw, size: 16, color: AppColors.teal),
                tooltip: 'adminTrend.refresh'.tr(),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          if (summary != null && summary!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(summary!,
                style: AppTypography.body(size: 13, color: AppColors.lightInk, height: 1.5)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _StatPill(label: 'adminTrend.posts24h'.tr(namedArgs: {'n': '$total24h'})),
              const SizedBox(width: 8),
              _StatPill(label: 'adminTrend.posts6h'.tr(namedArgs: {'n': '$total6h'})),
              if (cached) ...[
                const SizedBox(width: 8),
                _StatPill(label: 'adminTrend.cached'.tr(), dim: true),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, this.dim = false});
  final String label;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dim ? Colors.grey.shade100 : AppColors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: AppTypography.body(
              size: 11,
              color: dim ? AppColors.lightMute : AppColors.teal,
              weight: FontWeight.w600)),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});
  final Map<String, dynamic> trend;

  IconData _dirIcon(String? dir) {
    switch (dir) {
      case 'up': return LucideIcons.trendingUp;
      case 'down': return LucideIcons.trendingDown;
      default: return LucideIcons.minus;
    }
  }

  Color _dirColor(String? dir) {
    switch (dir) {
      case 'up': return Colors.green.shade600;
      case 'down': return Colors.red.shade500;
      default: return AppColors.lightMute;
    }
  }

  Color _sentimentColor(String? s) {
    switch (s) {
      case 'positiv': return Colors.green.shade600;
      case 'negativ': return Colors.red.shade500;
      default: return AppColors.lightMute;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = trend['topic'] as String? ?? '';
    final volume = trend['volume'] as int? ?? 0;
    final direction = trend['direction'] as String?;
    final sentiment = trend['sentiment'] as String?;
    final note = trend['note'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(topic,
                    style: AppTypography.body(size: 14, color: AppColors.lightInk,
                        weight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Icon(_dirIcon(direction), size: 18, color: _dirColor(direction)),
              const SizedBox(width: 4),
              Text(
                'adminTrend.direction.$direction'.tr(),
                style: AppTypography.body(size: 11, color: _dirColor(direction),
                    weight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'adminTrend.volume'.tr(namedArgs: {'n': '$volume'}),
                style: AppTypography.body(size: 11, color: AppColors.lightMute),
              ),
              if (sentiment != null) ...[
                const SizedBox(width: 12),
                Icon(LucideIcons.heart, size: 11, color: _sentimentColor(sentiment)),
                const SizedBox(width: 3),
                Text(
                  'adminTrend.sentiment.$sentiment'.tr(),
                  style: AppTypography.body(size: 11,
                      color: _sentimentColor(sentiment)),
                ),
              ],
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: AppTypography.body(size: 12, color: AppColors.lightInkSoft)),
          ],
        ],
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
          Icon(LucideIcons.barChart2, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('adminTrend.empty'.tr(),
              style: AppTypography.body(size: 13, color: AppColors.lightMute)),
        ],
      ),
    );
  }
}
