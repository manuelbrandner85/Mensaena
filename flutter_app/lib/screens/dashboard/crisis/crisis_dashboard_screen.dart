import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/crisis.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/module_search_bar.dart';

/// SKILL: mensaena-features + mensaena-design
/// Krisen-Dashboard — 1:1-Spiegel von `src/app/dashboard/crisis/page.tsx`.
/// Features: Stats-Bar (active/in_progress/resolved/critical), Multi-Filter
/// (Status + Kategorie + Dringlichkeit), Suche, SOS-FAB + SOS-Modal mit
/// Quick-Help-Numbers, Inline-Resources-CTA, Active-Crisis-Banner.
class CrisisDashboardScreen extends ConsumerStatefulWidget {
  const CrisisDashboardScreen({super.key});

  @override
  ConsumerState<CrisisDashboardScreen> createState() =>
      _CrisisDashboardScreenState();
}

class _CrisisDashboardScreenState
    extends ConsumerState<CrisisDashboardScreen> {
  // 11 Kategorien aus CRISIS_CATEGORY_CONFIG.
  static const List<FilterOption<String>> _categories = [
    FilterOption(value: 'medical', label: '🏥 Medizinisch'),
    FilterOption(value: 'fire', label: '🔥 Brand'),
    FilterOption(value: 'flood', label: '🌊 Hochwasser'),
    FilterOption(value: 'storm', label: '⛈️ Unwetter'),
    FilterOption(value: 'accident', label: '🚗 Unfall'),
    FilterOption(value: 'violence', label: '🛡️ Gewalt'),
    FilterOption(value: 'missing_person', label: '🔍 Vermisst'),
    FilterOption(value: 'infrastructure', label: '🏗️ Infrastruktur'),
    FilterOption(value: 'supply', label: '📦 Versorgung'),
    FilterOption(value: 'evacuation', label: '🚨 Evakuierung'),
    FilterOption(value: 'other', label: '❓ Sonstiges'),
  ];

  static const List<FilterOption<String>> _urgencies = [
    FilterOption(value: 'critical', label: '🔴 Kritisch'),
    FilterOption(value: 'high', label: '🟠 Hoch'),
    FilterOption(value: 'medium', label: '🟡 Mittel'),
    FilterOption(value: 'low', label: '🔵 Niedrig'),
  ];

  String _search = '';
  String? _category;
  String? _urgency;

  bool get _hasFilters =>
      _search.isNotEmpty || _category != null || _urgency != null;

  void _reset() {
    setState(() {
      _search = '';
      _category = null;
      _urgency = null;
    });
  }

  List<Crisis> _apply(List<Crisis> all) {
    final q = _search.trim().toLowerCase();
    return all.where((c) {
      if (_category != null && c.category != _category) return false;
      if (_urgency != null && c.urgency != _urgency) return false;
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeCrisesProvider);
    return DashboardScaffold(
      title: 'Krisenmodus',
      currentRoute: '/dashboard/crisis',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.herzrot,
        foregroundColor: AppColors.ink,
        onPressed: () => _openSosModal(context),
        icon: const Icon(LucideIcons.alertTriangle),
        label: const Text('SOS'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: ModuleSearchBar(
                hintText: 'Krisen durchsuchen…',
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            // ── Kategorie ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: FilterChipBar<String>(
                options: _categories,
                selected: _category == null ? const <String>{} : {_category!},
                onChanged: (s) =>
                    setState(() => _category = s.isEmpty ? null : s.first),
              ),
            ),
            // ── Dringlichkeit ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: FilterChipBar<String>(
                options: _urgencies,
                selected: _urgency == null ? const <String>{} : {_urgency!},
                allLabel: 'Alle Dringlichkeiten',
                onChanged: (s) =>
                    setState(() => _urgency = s.isEmpty ? null : s.first),
              ),
            ),
            if (_hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ActiveFilterStrip(
                  chips: [
                    if (_category != null)
                      ActiveFilterChip(
                        label: _categories
                            .firstWhere((c) => c.value == _category)
                            .label,
                        onRemove: () => setState(() => _category = null),
                      ),
                    if (_urgency != null)
                      ActiveFilterChip(
                        label: _urgencies
                            .firstWhere((u) => u.value == _urgency)
                            .label,
                        onRemove: () => setState(() => _urgency = null),
                      ),
                    if (_search.isNotEmpty)
                      ActiveFilterChip(
                        label: '🔍 $_search',
                        onRemove: () => setState(() => _search = ''),
                      ),
                  ],
                  onClearAll: _reset,
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.herzrot,
                backgroundColor: AppColors.surface,
                onRefresh: () async => ref.refresh(activeCrisesProvider),
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.herzrot),
                  ),
                  error: (e, _) => Center(
                    child:
                        Text('Fehler: $e', style: AppTypography.caption()),
                  ),
                  data: (all) {
                    final list = _apply(all);
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _StatsBar(all: all),
                        const SizedBox(height: 12),
                        if (all.any((c) => c.urgency == 'critical')) ...[
                          _CriticalBanner(
                            count: all
                                .where((c) => c.urgency == 'critical')
                                .length,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Text(
                              '${list.length} Krise${list.length == 1 ? "" : "n"}',
                              style: AppTypography.label(size: 10),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () =>
                                  context.go('/dashboard/crisis/create'),
                              icon: const Icon(LucideIcons.plus,
                                  size: 12, color: AppColors.amber),
                              label: Text('Melden',
                                  style: AppTypography.label(
                                      size: 10,
                                      color: AppColors.amber)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (list.isEmpty)
                          EmptyStateCard(
                            icon: LucideIcons.shieldCheck,
                            color: AppColors.leben,
                            title: _hasFilters
                                ? 'Keine Treffer.'
                                : 'Aktuell keine aktiven Krisen.',
                            description: _hasFilters
                                ? 'Andere Filter probieren.'
                                : 'Im Notfall: 112. Krise hier melden — sammelt schnelle Hilfsangebote aus deiner Nachbarschaft.',
                            actionLabel: _hasFilters
                                ? 'Filter zurücksetzen'
                                : 'Krise melden',
                            onAction: _hasFilters
                                ? _reset
                                : () =>
                                    context.go('/dashboard/crisis/create'),
                          )
                        else
                          ...list.map((c) => _CrisisTile(crisis: c)),
                        const SizedBox(height: 16),
                        _ResourcesCta(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SOS-Modal ────────────────────────────────────────────────────────
  void _openSosModal(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _SosSheet(
        onReport: () {
          Navigator.pop(sheetCtx);
          context.go('/dashboard/crisis/create');
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Stats-Bar
// ─────────────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.all});
  final List<Crisis> all;

  @override
  Widget build(BuildContext context) {
    final active = all.where((c) => c.status == 'active').length;
    final inProgress = all.where((c) => c.status == 'in_progress').length;
    final critical = all.where((c) => c.urgency == 'critical').length;
    final helpers = all.fold<int>(0, (sum, c) => sum + (c.helperCount ?? 0));
    return Row(
      children: [
        Expanded(
            child: _stat('Aktiv', active, AppColors.herzrot,
                LucideIcons.alertTriangle)),
        const SizedBox(width: 8),
        Expanded(
            child: _stat('In Arbeit', inProgress, AppColors.amber,
                LucideIcons.clock)),
        const SizedBox(width: 8),
        Expanded(
            child: _stat('Kritisch', critical, AppColors.herzrotWarm,
                LucideIcons.flame)),
        const SizedBox(width: 8),
        Expanded(
            child: _stat('Helfer', helpers, AppColors.leben,
                LucideIcons.helpingHand)),
      ],
    );
  }

  Widget _stat(String label, int n, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text('$n',
              style: AppTypography.mono(size: 18, color: AppColors.ink)),
          Text(label, style: AppTypography.label(size: 8, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Critical Banner
// ─────────────────────────────────────────────────────────────────────────
class _CriticalBanner extends StatelessWidget {
  const _CriticalBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.herzrot.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.herzrot.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle,
              color: AppColors.herzrotWarm, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count kritische Krise${count == 1 ? "" : "n"} aktiv — Hilfe wird gebraucht.',
              style: AppTypography.body(
                size: 13,
                color: AppColors.herzrotWarm,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SOS-Sheet (1:1 SOSModal.tsx)
// ─────────────────────────────────────────────────────────────────────────
class _SosSheet extends StatelessWidget {
  const _SosSheet({required this.onReport});
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 14),
          Text('SOS – Soforthilfe',
              style: AppTypography.display(
                  size: 22, color: AppColors.ink)),
          const SizedBox(height: 14),
          _SosRow(
            icon: LucideIcons.phone,
            iconBg: AppColors.herzrot,
            title: '112 anrufen',
            subtitle:
                'EU-weit kostenlos, 24/7 – Feuerwehr & Rettung',
            onTap: () => launchUrl(Uri.parse('tel:112')),
            big: true,
          ),
          _SosRow(
            icon: LucideIcons.shieldCheck,
            iconBg: AppColors.teal,
            title: 'Polizei: 110',
            subtitle: 'Deutschlandweit kostenlos, 24/7',
            onTap: () => launchUrl(Uri.parse('tel:110')),
          ),
          _SosRow(
            icon: LucideIcons.alertTriangle,
            iconBg: AppColors.amber,
            title: 'Krise melden',
            subtitle:
                'Nachbarn mobilisieren und Hilfe koordinieren',
            onTap: onReport,
          ),
          _SosRow(
            icon: LucideIcons.heart,
            iconBg: AppColors.tealSoft,
            title: 'TelefonSeelsorge: 0800 111 0 111',
            subtitle: 'Kostenlos, anonym, 24/7',
            onTap: () => launchUrl(Uri.parse('tel:08001110111')),
          ),
          _SosRow(
            icon: LucideIcons.stethoscope,
            iconBg: AppColors.amber,
            title: 'Ärztlicher Bereitschaftsdienst: 116 117',
            subtitle: 'DE — Krankenversicherung-Hilfe',
            onTap: () => launchUrl(Uri.parse('tel:116117')),
          ),
          const SizedBox(height: 12),
          Text(
            'Bei akuter Lebensgefahr immer zuerst 112 anrufen!',
            textAlign: TextAlign.center,
            style: AppTypography.caption(),
          ),
        ],
      ),
    );
  }
}

class _SosRow extends StatelessWidget {
  const _SosRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.big = false,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          border: Border.all(
            color: big
                ? AppColors.herzrot.withValues(alpha: 0.5)
                : AppColors.line,
            width: big ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: big ? 50 : 38,
              height: big ? 50 : 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: AppColors.voidColor, size: big ? 22 : 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.body(
                        size: big ? 16 : 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.caption()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Resources CTA + Crisis Tile (vorhanden, leicht modifiziert)
// ─────────────────────────────────────────────────────────────────────────
class _ResourcesCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/dashboard/crisis/resources'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.phone, color: AppColors.herzrot),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notruf-Nummern',
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '112 · 110 · 116117 · Telefonseelsorge 0800 1110111',
                    style: AppTypography.caption(),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: AppColors.amber),
          ],
        ),
      ),
    );
  }
}

class _CrisisTile extends StatelessWidget {
  const _CrisisTile({required this.crisis});
  final Crisis crisis;

  static const Map<String, Color> _urgencyColors = {
    'critical': AppColors.herzrot,
    'high': Color(0xFFFB923C),
    'medium': AppColors.amber,
    'low': AppColors.teal,
  };

  static const Map<String, String> _urgencyLabel = {
    'critical': 'KRITISCH',
    'high': 'HOCH',
    'medium': 'MITTEL',
    'low': 'NIEDRIG',
  };

  @override
  Widget build(BuildContext context) {
    final color = _urgencyColors[crisis.urgency] ?? AppColors.amber;
    return InkWell(
      onTap: () => context.go('/dashboard/crisis/${crisis.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border:
              Border.all(color: color.withValues(alpha: 0.5), width: 1.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _urgencyLabel[crisis.urgency] ??
                        crisis.urgency.toUpperCase(),
                    style: AppTypography.label(
                      size: 9,
                      color: AppColors.voidColor,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  crisis.category.toUpperCase(),
                  style: AppTypography.label(size: 9, color: color),
                ),
                const Spacer(),
                if (crisis.createdAt != null)
                  Text(
                    DateFormat('dd.MM. HH:mm').format(crisis.createdAt!),
                    style: AppTypography.caption(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              crisis.title,
              style: AppTypography.display(
                size: 18,
                color: AppColors.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              crisis.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 13,
                color: AppColors.inkSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(LucideIcons.helpingHand,
                    size: 12, color: AppColors.leben),
                const SizedBox(width: 4),
                Text(
                  '${crisis.helperCount ?? 0} Helfer:in',
                  style: AppTypography.mono(
                      size: 11, color: AppColors.lebenSoft),
                ),
                const Spacer(),
                if (crisis.locationText != null) ...[
                  const Icon(LucideIcons.mapPin,
                      size: 12, color: AppColors.mute),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      crisis.locationText!,
                      style: AppTypography.body(
                        size: 11,
                        color: AppColors.mute,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
