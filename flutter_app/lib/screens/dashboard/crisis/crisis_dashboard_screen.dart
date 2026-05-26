import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/emergency_numbers_config.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/crisis.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/locale_country_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/crisis/safe_checkin_button.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/location_map_view.dart';
import '../../../widgets/shared/module_search_bar.dart';
import '../../../widgets/shared/view_toggle.dart';

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
  List<FilterOption<String>> get _categories => [
        FilterOption(value: 'medical', label: 'crisis.catMedical'.tr()),
        FilterOption(value: 'fire', label: 'crisis.catFire'.tr()),
        FilterOption(value: 'flood', label: 'crisis.catFlood'.tr()),
        FilterOption(value: 'storm', label: 'crisis.catStorm'.tr()),
        FilterOption(value: 'accident', label: 'crisis.catAccident'.tr()),
        FilterOption(value: 'violence', label: 'crisis.catViolence'.tr()),
        FilterOption(value: 'missing_person', label: 'crisis.catMissing'.tr()),
        FilterOption(
            value: 'infrastructure', label: 'crisis.catInfrastructure'.tr()),
        FilterOption(value: 'supply', label: 'crisis.catSupply'.tr()),
        FilterOption(value: 'evacuation', label: 'crisis.catEvacuation'.tr()),
        FilterOption(value: 'other', label: 'crisis.catOther'.tr()),
      ];

  List<FilterOption<String>> get _urgencies => [
        FilterOption(value: 'critical', label: 'crisis.urgCritical'.tr()),
        FilterOption(value: 'high', label: 'crisis.urgHigh'.tr()),
        FilterOption(value: 'medium', label: 'crisis.urgMedium'.tr()),
        FilterOption(value: 'low', label: 'crisis.urgLow'.tr()),
      ];

  String _search = '';
  String? _category;
  String? _urgency;
  _CrisisView _view = _CrisisView.list;

  bool get _hasFilters =>
      _search.isNotEmpty || _category != null || _urgency != null;

  static Color _urgencyColor(String u) {
    switch (u) {
      case 'critical':
        return AppColors.herzrot;
      case 'high':
        return const Color(0xFFFB923C);
      case 'medium':
        return AppColors.amber;
      default:
        return AppColors.teal;
    }
  }

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
      title: 'crisis.title'.tr(),
      currentRoute: '/dashboard/crisis',
      fab: _PulsingSosFab(onPressed: () {
        Haptics.heavyImpact();
        _openSosModal(context);
      }),
      body: SafeArea(
        child: Column(
          children: [
            const _SosTopBanner(),
            // K3: 'Ich bin sicher'-Banner bei aktiver kritischer Krise.
            // Erscheint nur wenn kritische Krise existiert; verschwindet
            // nach erfolgreichem Check-In (12h Cooldown).
            const SafeCheckinButton(),
            // FIX (User-Wunsch: "in krisenmodus soll auch krise melden
            // können"): prominenter Report-Button DIREKT unter dem
            // SOS-Banner, damit der User sofort sieht wo er eine Krise
            // melden kann.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: _ReportCrisisButton(
                onTap: () => context.push('/dashboard/crisis/create'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 09',
                metaCategory: 'crisis.title'.tr(),
                title: 'crisis.moduleTitle'.tr(),
                subtitle: 'crisis.moduleSubtitle'.tr(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ModuleSearchBar(
                      hintText: 'crisis.searchPlaceholder'.tr(),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ViewToggle<_CrisisView>(
                    value: _view,
                    onChanged: (v) => setState(() => _view = v),
                    options: [
                      ViewToggleOption(
                          value: _CrisisView.list,
                          label: 'crisis.viewList'.tr(),
                          icon: LucideIcons.list),
                      ViewToggleOption(
                          value: _CrisisView.map,
                          label: 'crisis.viewMap'.tr(),
                          icon: LucideIcons.mapPin),
                    ],
                  ),
                ],
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
                allLabel: 'crisis.allUrgencies'.tr(),
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
                    child: Text(
                        'crisis.error'.tr(namedArgs: {'error': '$e'}),
                        style: AppTypography.caption()),
                  ),
                  data: (all) {
                    final list = _apply(all);
                    if (_view == _CrisisView.map) {
                      return LocationMapView(
                        markers: [
                          for (final c in list)
                            MapMarkerData(
                              id: c.id,
                              lat: c.latitude,
                              lng: c.longitude,
                              color: _urgencyColor(c.urgency),
                              title: c.title,
                              subtitle: c.locationText,
                              icon: LucideIcons.alertTriangle,
                            ),
                        ],
                        onMarkerTap: (m) =>
                            context.go('/dashboard/crisis/${m.id}'),
                      );
                    }
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
                              (list.length == 1
                                      ? 'crisis.countOne'
                                      : 'crisis.countOther')
                                  .tr(namedArgs: {'count': '${list.length}'}),
                              style: AppTypography.label(size: 10),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () =>
                                  context.push('/dashboard/crisis/create'),
                              icon: const Icon(LucideIcons.plus,
                                  size: 12, color: AppColors.amber),
                              label: Text('crisis.report'.tr(),
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
                                ? 'crisis.noResults'.tr()
                                : 'crisis.noActive'.tr(),
                            description: _hasFilters
                                ? 'crisis.tryOtherFilters'.tr()
                                : 'crisis.emergencyHint'.tr(),
                            actionLabel: _hasFilters
                                ? 'crisis.resetFilters'.tr()
                                : 'crisis.reportCrisis'.tr(),
                            onAction: _hasFilters
                                ? _reset
                                : () =>
                                    context.push('/dashboard/crisis/create'),
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
          context.push('/dashboard/crisis/create');
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
            child: _stat('crisis.statAktiv'.tr(), active, AppColors.herzrot,
                LucideIcons.alertTriangle)),
        const SizedBox(width: 8),
        Expanded(
            child: _stat('crisis.statInArbeit'.tr(), inProgress, AppColors.amber,
                LucideIcons.clock)),
        const SizedBox(width: 8),
        Expanded(
            child: _stat('crisis.statKritisch'.tr(), critical, AppColors.herzrotWarm,
                LucideIcons.flame)),
        const SizedBox(width: 8),
        Expanded(
            child: _stat('crisis.statHelfer'.tr(), helpers, AppColors.leben,
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
class _CriticalBanner extends StatefulWidget {
  const _CriticalBanner({required this.count});
  final int count;

  @override
  State<_CriticalBanner> createState() => _CriticalBannerState();
}

class _CriticalBannerState extends State<_CriticalBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        // Sin-Wave-Pulse: 0..1..0
        final wave = (0.5 + 0.5 * (_ctrl.value < 0.5
            ? _ctrl.value * 2
            : (1 - _ctrl.value) * 2));
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.herzrot
                .withValues(alpha: 0.14 + wave * 0.10),
            border: Border.all(
              color: AppColors.herzrot
                  .withValues(alpha: 0.5 + wave * 0.4),
              width: 1.2 + wave * 0.6,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.herzrot
                    .withValues(alpha: 0.15 + wave * 0.35),
                blurRadius: 8 + wave * 16,
                spreadRadius: wave * 2,
              ),
            ],
          ),
          child: Row(
            children: [
              // Pulsing red dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.herzrot,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.herzrot
                          .withValues(alpha: 0.7 * wave),
                      blurRadius: 4 + wave * 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(LucideIcons.alertTriangle,
                  color: AppColors.herzrotWarm, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (widget.count == 1
                          ? 'crisis.criticalActiveOne'
                          : 'crisis.criticalActiveOther')
                      .tr(namedArgs: {'count': '${widget.count}'}),
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
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SOS-Sheet — Dynamisch, country-aware, max 2 Taps zum Anruf.
// ─────────────────────────────────────────────────────────────────────────
class _SosSheet extends StatefulWidget {
  const _SosSheet({required this.onReport});
  final VoidCallback onReport;

  @override
  State<_SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<_SosSheet> {
  String? _selectedCountry;

  String get _country {
    return _selectedCountry ?? LocaleCountryService.forContext(context);
  }

  Future<void> _dial(String number) async {
    Haptics.heavyImpact();
    final sanitized = number.replaceAll(RegExp(r'[\s\-()]'), '');
    await launchUrl(Uri.parse('tel:$sanitized'));
  }

  void _openCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('crisis.selectCountry'.tr(),
                        style: AppTypography.display(
                            size: 18, color: AppColors.ink)),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: AppColors.mute),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: kCountryEmergencyConfigs.length,
                itemBuilder: (_, i) {
                  final cfg = kCountryEmergencyConfigs[i];
                  final active = cfg.code == _country;
                  return ListTile(
                    leading: Text(cfg.flag,
                        style: const TextStyle(fontSize: 24)),
                    title: Text(cfg.label,
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        )),
                    subtitle: Text('${cfg.code} · ${cfg.emergency}',
                        style: AppTypography.caption()),
                    trailing: active
                        ? const Icon(LucideIcons.check,
                            color: AppColors.amber)
                        : null,
                    onTap: () {
                      setState(() => _selectedCountry = cfg.code);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final country = _country;
    final config = getCountryConfig(country) ??
        getCountryConfig('DE')!; // Hard fallback DE

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag-Handle
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
              Text('crisis.sosTitle'.tr(),
                  style: AppTypography.display(
                      size: 22, color: AppColors.ink)),
              const SizedBox(height: 12),
              // Country-Chip-Row: DACH + Mehr Länder
              _CountryChipRow(
                selected: country,
                onSelect: (c) => setState(() => _selectedCountry = c),
                onMore: _openCountryPicker,
              ),
              const SizedBox(height: 16),
              // ── Großer Notruf-Button ───────────────────────────
              _BigEmergencyButton(
                number: config.emergency,
                onTap: () => _dial(config.emergency),
              ),
              const SizedBox(height: 10),
              // ── Polizei ───────────────────────────────────────
              _MediumActionButton(
                icon: LucideIcons.shield,
                iconColor: AppColors.teal,
                number: config.police,
                label: 'crisis.countryPolice'.tr(),
                onTap: () => _dial(config.police),
              ),
              const SizedBox(height: 10),
              // ── Krise melden (prominent) ──────────────────────
              _ReportCrisisButton(onTap: widget.onReport),
              const SizedBox(height: 10),
              // ── Mental Health ─────────────────────────────────
              if (config.crisisHotline != null)
                _SmallSosRow(
                  icon: LucideIcons.heart,
                  iconBg: AppColors.tealSoft,
                  number: config.crisisHotline!,
                  title: 'crisis.mentalHealth'.tr(),
                  subtitle: config.crisisHotlineLabel,
                  onTap: () => _dial(config.crisisHotline!),
                  height: 56,
                ),
              if (config.childHotline != null)
                _SmallSosRow(
                  icon: LucideIcons.baby,
                  iconBg: AppColors.amber,
                  number: config.childHotline!,
                  title: 'crisis.childHelp'.tr(),
                  onTap: () => _dial(config.childHotline!),
                  height: 48,
                ),
              if (config.womenHotline != null)
                _SmallSosRow(
                  icon: LucideIcons.users,
                  iconBg: AppColors.herzrotWarm,
                  number: config.womenHotline!,
                  title: 'crisis.womenHelp'.tr(),
                  onTap: () => _dial(config.womenHotline!),
                  height: 48,
                ),
              if (config.poisonHotline != null)
                _SmallSosRow(
                  icon: LucideIcons.flaskConical,
                  iconBg: AppColors.leben,
                  number: config.poisonHotline!,
                  title: 'crisis.poisonHelp'.tr(),
                  onTap: () => _dial(config.poisonHotline!),
                  height: 48,
                ),
              const SizedBox(height: 14),
              Center(
                child: TextButton.icon(
                  icon: const Icon(LucideIcons.list,
                      size: 14, color: AppColors.amber),
                  label: Text('crisis.allNumbers'.tr(),
                      style: AppTypography.label(
                          size: 11, color: AppColors.amber)),
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/dashboard/crisis/resources');
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Country-Chip-Row (DACH + "Mehr Länder") ─────────────────────────────
class _CountryChipRow extends StatelessWidget {
  const _CountryChipRow({
    required this.selected,
    required this.onSelect,
    required this.onMore,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          for (final cfg in kDachCountries) ...[
            _CountryChip(
              flag: cfg.flag,
              label: cfg.code,
              active: cfg.code == selected,
              onTap: () => onSelect(cfg.code),
            ),
            const SizedBox(width: 6),
          ],
          // "Mehr Länder" mit aktivem Land falls nicht DACH
          () {
            final isDach =
                selected == 'DE' || selected == 'AT' || selected == 'CH';
            final cfg = getCountryConfig(selected);
            if (!isDach && cfg != null) {
              return _CountryChip(
                flag: cfg.flag,
                label: cfg.code,
                active: true,
                onTap: onMore,
              );
            }
            return _CountryChip(
              flag: '🌍',
              label: 'crisis.moreCountries'.tr(),
              active: false,
              onTap: onMore,
            );
          }(),
        ],
      ),
    );
  }
}

class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.flag,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String flag;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.amber.withValues(alpha: 0.20)
              : AppColors.surface,
          border: Border.all(
            color: active
                ? AppColors.amber.withValues(alpha: 0.7)
                : AppColors.line,
            width: active ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(label,
                style: AppTypography.label(
                  size: 11,
                  color: active ? AppColors.amber : AppColors.mute,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Big Emergency-Button (88dp, gradient herzrot) ───────────────────────
class _BigEmergencyButton extends StatelessWidget {
  const _BigEmergencyButton({required this.number, required this.onTap});

  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.herzrot, AppColors.herzrotWarm],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.herzrot.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.phone, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(number,
                      style: AppTypography.mono(
                        size: 36,
                        color: Colors.white,
                        weight: FontWeight.w800,
                      )),
                  Text('crisis.callNow'.tr(),
                      style: AppTypography.label(
                          size: 10, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Medium Button (64dp): Polizei ───────────────────────────────────────
class _MediumActionButton extends StatelessWidget {
  const _MediumActionButton({
    required this.icon,
    required this.iconColor,
    required this.number,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String number;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(number,
                      style: AppTypography.mono(
                        size: 18,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                      )),
                  Text(label, style: AppTypography.caption()),
                ],
              ),
            ),
            const Icon(LucideIcons.phone, color: AppColors.mute, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── "Krise melden"-Button (prominent, amber-tint) ───────────────────────
class _ReportCrisisButton extends StatelessWidget {
  const _ReportCrisisButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.16),
          border: Border.all(
            color: AppColors.amber.withValues(alpha: 0.6),
            width: 1.4,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.amber,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.alertTriangle,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('crisis.reportCrisisProminent'.tr(),
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                      )),
                  Text('crisis.reportCrisisHint'.tr(),
                      style: AppTypography.caption()),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                color: AppColors.amber, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Small Row (Mental/Children/Women/Poison) ────────────────────────────
class _SmallSosRow extends StatelessWidget {
  const _SmallSosRow({
    required this.icon,
    required this.iconBg,
    required this.number,
    required this.title,
    required this.onTap,
    required this.height,
    this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final String number;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconBg, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w600,
                        )),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption()),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(number,
                  style: AppTypography.mono(
                    size: 12,
                    color: AppColors.amber,
                    weight: FontWeight.w700,
                  )),
              const SizedBox(width: 4),
              const Icon(LucideIcons.phone,
                  size: 14, color: AppColors.mute),
            ],
          ),
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
      onTap: () => context.push('/dashboard/crisis/resources'),
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
                    'crisis.emergencyNumbers'.tr(),
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'crisis.emergencyNumbersList'.tr(),
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

  static String _urgencyLabel(String u) {
    switch (u) {
      case 'critical':
        return 'crisis.urgencyCritical'.tr();
      case 'high':
        return 'crisis.urgencyHigh'.tr();
      case 'medium':
        return 'crisis.urgencyMedium'.tr();
      case 'low':
        return 'crisis.urgencyLow'.tr();
      default:
        return u.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _urgencyColors[crisis.urgency] ?? AppColors.amber;
    // Kritische Krisen bekommen 3.5dp-Border + Glow.
    final isCritical = crisis.urgency == 'critical';
    return InkWell(
      onTap: () => context.go('/dashboard/crisis/${crisis.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isCritical ? 0.12 : 0.08),
          border: Border.all(
            color: color.withValues(alpha: isCritical ? 0.85 : 0.5),
            width: isCritical ? 3.5 : 1.4,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isCritical
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
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
                    _urgencyLabel(crisis.urgency),
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
                  'crisis.helpersCount'.tr(namedArgs: {'count': '${crisis.helperCount ?? 0}'}),
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


enum _CrisisView { list, map }

// Pulsierender SOS-FAB — bei Notfall mit zitternder Hand maximal sichtbar.
class _PulsingSosFab extends StatefulWidget {
  const _PulsingSosFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_PulsingSosFab> createState() => _PulsingSosFabState();
}

class _PulsingSosFabState extends State<_PulsingSosFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final wave = (0.5 + 0.5 * (_ctrl.value < 0.5
            ? _ctrl.value * 2
            : (1 - _ctrl.value) * 2));
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.herzrot.withValues(alpha: 0.35 + wave * 0.35),
                blurRadius: 16 + wave * 22,
                spreadRadius: wave * 4,
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.herzrot,
            foregroundColor: AppColors.ink,
            onPressed: widget.onPressed,
            extendedPadding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            icon: const Icon(LucideIcons.alertTriangle, size: 22),
            label: Text(
              'SOS',
              style: AppTypography.body(
                size: 17,
                color: AppColors.ink,
                weight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── SOS Top-Banner — prominenter Country-Notruf + Safe-Check-In ──────
class _SosTopBanner extends StatelessWidget {
  const _SosTopBanner();

  @override
  Widget build(BuildContext context) {
    // Dynamische Country-spezifische Emergency-Nummer.
    final country = LocaleCountryService.forContext(context);
    final config = getCountryConfig(country);
    final emergency = config?.emergency ?? '112';
    final flag = config?.flag ?? '🌍';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.herzrot, AppColors.herzrotWarm],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.herzrot.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text('crisis.lifeThreat'.tr(),
                        style: AppTypography.body(
                            size: 11,
                            color: Colors.white,
                            weight: FontWeight.w600,
                            letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    'crisis.call112Now'.tr().replaceAll('112', emergency),
                    style: AppTypography.display(
                        size: 18, color: Colors.white, height: 1.1)),
                const SizedBox(height: 6),
                // Quick-Link zu allen Notruf-Nummern (Polizei/Gift/Frauen/etc.)
                InkWell(
                  onTap: () => context.push('/dashboard/crisis/resources'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.phone,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'crisis.emergencyQuickAccess'.tr(),
                          style: AppTypography.label(
                              size: 9, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Safe-Check-In: schneller Status für Familie
          OutlinedButton.icon(
            onPressed: () => _sendSafeCheckIn(context),
            icon: const Icon(LucideIcons.shieldCheck,
                size: 14, color: Colors.white),
            label: Text('crisis.imSafe'.tr(),
                style: AppTypography.label(
                    size: 9, color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Country-spezifischer Emergency-Call
          InkWell(
            onTap: () => launchUrl(Uri.parse('tel:$emergency')),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.95),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(emergency,
                  style: const TextStyle(
                    color: AppColors.herzrot,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSafeCheckIn(BuildContext context) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      // Status broadcast via user_status + thanks an Profil-Kontakte.
      await sb.from('user_status').upsert({
        'user_id': uid,
        'status': 'safe',
        'status_text': 'crisis.safeStatusText'.tr(namedArgs: {
          'time': DateTime.now().toLocal().toIso8601String().substring(11, 16),
        }),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('crisis.safeCheckSent'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.leben)),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('crisis.error'.tr(namedArgs: {'error': '$e'}),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    }
  }
}
