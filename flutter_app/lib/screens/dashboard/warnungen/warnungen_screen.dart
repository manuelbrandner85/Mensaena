import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/app_config.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/nina_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// NINA-Warnungen (Bundesamt fuer Bevoelkerungsschutz und Katastrophenhilfe).
/// Sortiert nach Severity (Extreme > Severe > Moderate > Minor).
/// 15min Cache via NinaService singleton.
class WarnungenScreen extends ConsumerStatefulWidget {
  const WarnungenScreen({super.key});

  @override
  ConsumerState<WarnungenScreen> createState() => _WarnungenScreenState();
}

class _WarnungenScreenState extends ConsumerState<WarnungenScreen> {
  Future<List<Map<String, dynamic>>>? _future;
  String get _ags => AppConfig.defaultAgs;

  @override
  void initState() {
    super.initState();
    _future = NinaService.instance.fetchDashboard(ags: _ags);
  }

  Future<void> _refresh() async {
    NinaService.instance.clearCache();
    final fresh = NinaService.instance.fetchDashboard(ags: _ags);
    setState(() => _future = fresh);
    await fresh;
  }

  void _openDetail(Map<String, dynamic> w) {
    final id = w['id'] as String? ?? w['identifier'] as String?;
    if (id == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DetailSheet(warningId: id, summary: w),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'NINA-Warnungen',
      currentRoute: '/dashboard/warnungen',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.herzrot,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                );
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 60),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            const Icon(
                              LucideIcons.shieldCheck,
                              size: 40,
                              color: AppColors.leben,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Keine aktiven Warnungen.',
                              style: AppTypography.display(
                                size: 22,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Daten vom Bundesamt für Bevölkerungsschutz '
                              'und Katastrophenhilfe (NINA). Letzte Pruefung: '
                              '${DateFormat('HH:mm').format(DateTime.now())}.',
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                size: 13,
                                color: AppColors.inkSoft,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/dashboard/warnungen/food'),
                              icon: const Icon(LucideIcons.apple, size: 16),
                              label:
                                  const Text('Lebensmittelwarnungen (BVL)'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.herzrot.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.herzrot.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.alertOctagon,
                          size: 18,
                          color: AppColors.herzrot,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${list.length} aktive Warnung'
                            '${list.length == 1 ? "" : "en"} — '
                            'Daten vom Bundesamt (15 Min Cache).',
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...list.map(
                    (w) => _WarningTile(warning: w, onTap: () => _openDetail(w)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.go('/dashboard/warnungen/food'),
                    icon: const Icon(LucideIcons.apple, size: 16),
                    label: const Text('Lebensmittelwarnungen (BVL)'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  const _WarningTile({required this.warning, required this.onTap});
  final Map<String, dynamic> warning;
  final VoidCallback onTap;

  static const Map<String, ({Color color, String label})> _severities = {
    'Extreme': (color: AppColors.herzrot, label: 'EXTREM'),
    'Severe': (color: Color(0xFFFB923C), label: 'SCHWER'),
    'Moderate': (color: AppColors.amber, label: 'MITTEL'),
    'Minor': (color: AppColors.teal, label: 'GERING'),
  };

  @override
  Widget build(BuildContext context) {
    final payload = warning['payload'] as Map<String, dynamic>?;
    final data = payload?['data'] as Map<String, dynamic>? ?? warning;
    final severity = (warning['severity'] ?? data['severity'])?.toString() ??
        'Moderate';
    final cfg = _severities[severity] ??
        (color: AppColors.amber, label: severity.toUpperCase());
    final headline =
        (warning['i18nTitle']?['de'] ?? data['headline'] ?? warning['headline'])
                ?.toString() ??
            'Warnung';
    final sentRaw = warning['sent'] ?? data['sent'];
    final sent = sentRaw is String ? DateTime.tryParse(sentRaw) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cfg.color.withValues(alpha: 0.08),
          border: Border.all(color: cfg.color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cfg.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    cfg.label,
                    style: AppTypography.label(
                      size: 9,
                      color: AppColors.voidColor,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
                const Spacer(),
                if (sent != null)
                  Text(
                    DateFormat('dd.MM. HH:mm').format(sent),
                    style: AppTypography.caption(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              headline,
              style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                weight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSheet extends StatefulWidget {
  const _DetailSheet({required this.warningId, required this.summary});
  final String warningId;
  final Map<String, dynamic> summary;

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  Future<Map<String, dynamic>?>? _future;

  @override
  void initState() {
    super.initState();
    _future = NinaService.instance.fetchWarningDetail(widget.warningId);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final headline = d?['info']?[0]?['headline'] ??
              widget.summary['i18nTitle']?['de'] ??
              widget.summary['headline'] ??
              'Warnung';
          final description = d?['info']?[0]?['description'] ?? '';
          final instruction = d?['info']?[0]?['instruction'] ?? '';
          final sender = d?['sender'] ?? widget.summary['sender'];
          return ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (snap.connectionState != ConnectionState.done)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                )
              else ...[
                Text(
                  headline.toString(),
                  style: AppTypography.display(
                    size: 22,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (description.toString().isNotEmpty)
                  Text(
                    description.toString(),
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.inkSoft,
                      height: 1.55,
                    ),
                  ),
                if (instruction.toString().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Handlungsempfehlung',
                      style: AppTypography.label(size: 10)),
                  const SizedBox(height: 4),
                  Text(
                    instruction.toString(),
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.amber,
                      height: 1.55,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
                if (sender != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Quelle: $sender',
                    style: AppTypography.caption(),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
