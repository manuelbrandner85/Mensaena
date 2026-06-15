import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/safety_report.dart';
import '../../../repositories/safety_repository.dart';
import '../../../services/location_service.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_widget.dart';
import '../../../widgets/shared/error_state_widget.dart';
import '../../../widgets/shared/location_map_view.dart';
import '../../../widgets/shared/view_toggle.dart';

enum _SafetyView { map, list }

/// SKILL: mensaena-features + impeccable
/// Safety — Nachbarschafts-Sicherheitsmeldungen. Karten-Ansicht (Standard) +
/// Listen-Ansicht mit Farbkodierung nach `incident_type`. Auto-Hide bei
/// >3 Content-Reports und Anonymisierung erledigt die RPC serverseitig.
class SafetyScreen extends ConsumerStatefulWidget {
  const SafetyScreen({super.key});

  @override
  ConsumerState<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends ConsumerState<SafetyScreen> {
  static const int _radiusKm = 5;

  _SafetyView _view = _SafetyView.map;
  Position? _pos;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final pos = await LocationService.getBestPosition();
    if (!mounted) return;
    setState(() {
      _pos = pos;
      _locating = false;
    });
  }

  SafetyNearbyArgs? get _args => _pos == null
      ? null
      : (lat: _pos!.latitude, lng: _pos!.longitude, radiusKm: _radiusKm);

  // ── Farbkodierung nach Vorfall-Typ ────────────────────────────────
  static Color colorFor(String type) {
    switch (type) {
      case SafetyIncidentType.einbruch:
        return AppColors.herzrot;
      case SafetyIncidentType.diebstahl:
        return AppColors.amber;
      case SafetyIncidentType.vandalismus:
        return AppColors.bronze;
      case SafetyIncidentType.verdaechtig:
        return AppColors.trust;
      case SafetyIncidentType.unfall:
        return AppColors.herzrotWarm;
      case SafetyIncidentType.fundgegenstand:
        return AppColors.leben;
      default:
        return AppColors.mute;
    }
  }

  static IconData iconFor(String type) {
    switch (type) {
      case SafetyIncidentType.einbruch:
        return LucideIcons.doorOpen;
      case SafetyIncidentType.diebstahl:
        return LucideIcons.shoppingBag;
      case SafetyIncidentType.vandalismus:
        return LucideIcons.hammer;
      case SafetyIncidentType.verdaechtig:
        return LucideIcons.eye;
      case SafetyIncidentType.unfall:
        return LucideIcons.car;
      case SafetyIncidentType.fundgegenstand:
        return LucideIcons.package;
      default:
        return LucideIcons.shieldAlert;
    }
  }

  static String labelFor(String type) => 'safety.types.$type'.tr();

  void _refresh() {
    final a = _args;
    if (a != null) ref.invalidate(safetyNearbyProvider(a));
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;

    // Realtime-Stream treibt den Live-Refresh der kuratierten RPC-Liste.
    ref.listen(safetyReportsStreamProvider, (_, __) => _refresh());

    return DashboardScaffold(
      title: 'safety.screenTitle'.tr(),
      currentRoute: '/dashboard/safety',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.herzrot,
        foregroundColor: AppColors.ink,
        onPressed: _openCreateSheet,
        icon: const Icon(LucideIcons.plus),
        label: Text('safety.create'.tr()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 14',
                metaCategory: 'safety.screenTitle'.tr(),
                title: 'safety.heroTitle'.tr(),
                subtitle: 'safety.heroSubtitle'.tr(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ViewToggle<_SafetyView>(
                    value: _view,
                    onChanged: (v) => setState(() => _view = v),
                    options: [
                      ViewToggleOption(
                        value: _SafetyView.map,
                        label: 'safety.viewMap'.tr(),
                        icon: LucideIcons.map,
                      ),
                      ViewToggleOption(
                        value: _SafetyView.list,
                        label: 'safety.viewList'.tr(),
                        icon: LucideIcons.list,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(args)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SafetyNearbyArgs? args) {
    if (_locating) return const ListSkeleton(count: 4);
    if (args == null) {
      return Center(
        child: EmptyStateWidget(
          icon: LucideIcons.mapPinOff,
          title: 'safety.locationRequired'.tr(),
          subtitle: 'safety.locationHint'.tr(),
          actionLabel: 'safety.useGps'.tr(),
          onAction: () {
            setState(() => _locating = true);
            _locate();
          },
        ),
      );
    }

    final async = ref.watch(safetyNearbyProvider(args));
    return async.when(
      loading: () => const ListSkeleton(count: 4),
      error: (_, __) => Center(
        child: ErrorStateWidget(onRetry: _refresh),
      ),
      data: (reports) {
        if (_view == _SafetyView.map) {
          return LocationMapView(
            markers: [
              for (final r in reports)
                MapMarkerData(
                  id: r.id,
                  lat: r.displayLat,
                  lng: r.displayLng,
                  color: colorFor(r.incidentType),
                  title: r.title,
                  subtitle: labelFor(r.incidentType),
                  icon: iconFor(r.incidentType),
                ),
            ],
            onMarkerTap: (m) {
              final match = reports.where((r) => r.id == m.id);
              if (match.isNotEmpty) _openDetailSheet(match.first);
            },
          );
        }
        if (reports.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 60),
              EmptyStateWidget(
                icon: LucideIcons.shieldCheck,
                title: 'safety.empty'.tr(),
                subtitle: 'safety.emptyHint'.tr(),
              ),
            ],
          );
        }
        return RefreshIndicator(
          color: AppColors.herzrot,
          backgroundColor: AppColors.surface,
          onRefresh: () async => _refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (context, i) => AnimatedEntrance(
              index: i,
              child: _SafetyTile(
                report: reports[i],
                onTap: () => _openDetailSheet(reports[i]),
                onUpvote: () => _upvote(reports[i]),
                onResolve: _isOwner(reports[i])
                    ? () => _resolve(reports[i])
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isOwner(SafetyReport r) =>
      !r.isAnonymous && r.reporterId == SupabaseService.currentUser?.id;

  Future<void> _upvote(SafetyReport r) async {
    final ok = await SafetyRepository.upvote(r.id);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.success(context, 'safety.upvoted'.tr());
      _refresh();
    } else {
      AppSnackBar.error(context, 'safety.upvoteError'.tr());
    }
  }

  Future<void> _resolve(SafetyReport r) async {
    final ok = await SafetyRepository.markResolved(r.id);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.success(context, 'safety.resolved'.tr());
      _refresh();
    } else {
      AppSnackBar.error(context, 'safety.resolveError'.tr());
    }
  }

  void _openDetailSheet(SafetyReport r) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SafetyDetailSheet(
        report: r,
        onUpvote: () {
          Navigator.of(context).pop();
          _upvote(r);
        },
        onResolve: _isOwner(r)
            ? () {
                Navigator.of(context).pop();
                _resolve(r);
              }
            : null,
      ),
    );
  }

  void _openCreateSheet() {
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SafetyCreateSheet(position: _pos),
    ).then((created) {
      if (created == true) _refresh();
    });
  }
}

// ──────────────────────────────────────────────────────────────────────
// Listen-Kachel
// ──────────────────────────────────────────────────────────────────────
class _SafetyTile extends StatelessWidget {
  const _SafetyTile({
    required this.report,
    required this.onTap,
    required this.onUpvote,
    this.onResolve,
  });

  final SafetyReport report;
  final VoidCallback onTap;
  final VoidCallback onUpvote;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final color = _SafetyScreenState.colorFor(report.incidentType);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border(
            left: BorderSide(color: color, width: 3),
            top: BorderSide(color: AppColors.line),
            right: BorderSide(color: AppColors.line),
            bottom: BorderSide(color: AppColors.line),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _SafetyScreenState.iconFor(report.incidentType),
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 15,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _SafetyScreenState.labelFor(report.incidentType),
                          style: AppTypography.label(size: 9, color: color),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        report.isAnonymous
                            ? LucideIcons.userX
                            : LucideIcons.user,
                        size: 11,
                        color: AppColors.mute,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          report.isAnonymous
                              ? 'safety.anonymousName'.tr()
                              : 'safety.neighbor'.tr(),
                          style: AppTypography.caption(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (report.locationAddress != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin,
                            size: 11, color: AppColors.mute),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            report.locationAddress!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                                size: 11, color: AppColors.mute),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'safety.upvote'.tr(),
                  onPressed: onUpvote,
                  icon: const Icon(LucideIcons.arrowBigUp, size: 18),
                  color: AppColors.herzrot,
                ),
                Text(
                  '${report.upvoteCount}',
                  style: AppTypography.mono(
                      size: 12, color: AppColors.inkSoft),
                ),
                if (onResolve != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'safety.markResolved'.tr(),
                    onPressed: onResolve,
                    icon: const Icon(LucideIcons.checkCircle, size: 16),
                    color: AppColors.leben,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Detail-Sheet
// ──────────────────────────────────────────────────────────────────────
class _SafetyDetailSheet extends StatelessWidget {
  const _SafetyDetailSheet({
    required this.report,
    required this.onUpvote,
    this.onResolve,
  });

  final SafetyReport report;
  final VoidCallback onUpvote;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final color = _SafetyScreenState.colorFor(report.incidentType);
    final df = DateFormat('dd.MM.yyyy, HH:mm');
    final when = report.happenedAt ?? report.createdAt;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_SafetyScreenState.iconFor(report.incidentType),
                    size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: AppTypography.display(
                          size: 18, color: AppColors.ink),
                    ),
                    Text(
                      _SafetyScreenState.labelFor(report.incidentType),
                      style: AppTypography.label(size: 10, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (report.description != null &&
              report.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              report.description!,
              style: AppTypography.body(
                  size: 14, color: AppColors.inkSoft, height: 1.5),
            ),
          ],
          const SizedBox(height: 14),
          _metaRow(LucideIcons.user,
              report.isAnonymous
                  ? 'safety.anonymousName'.tr()
                  : 'safety.neighbor'.tr()),
          if (report.locationAddress != null)
            _metaRow(LucideIcons.mapPin, report.locationAddress!),
          if (when != null)
            _metaRow(LucideIcons.clock, df.format(when.toLocal())),
          _metaRow(LucideIcons.arrowBigUp,
              'safety.upvotesCount'.tr(
                  namedArgs: {'count': '${report.upvoteCount}'})),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.herzrot,
                    foregroundColor: AppColors.ink,
                  ),
                  onPressed: onUpvote,
                  icon: const Icon(LucideIcons.arrowBigUp, size: 18),
                  label: Text('safety.upvote'.tr()),
                ),
              ),
              if (onResolve != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.leben,
                      side: BorderSide(
                          color: AppColors.leben.withValues(alpha: 0.5)),
                    ),
                    onPressed: onResolve,
                    icon: const Icon(LucideIcons.checkCircle, size: 18),
                    label: Text('safety.markResolved'.tr()),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.mute),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style:
                      AppTypography.body(size: 13, color: AppColors.inkSoft)),
            ),
          ],
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────
// Create-Sheet (kompaktes Formular)
// ──────────────────────────────────────────────────────────────────────
class _SafetyCreateSheet extends StatefulWidget {
  const _SafetyCreateSheet({this.position});
  final Position? position;

  @override
  State<_SafetyCreateSheet> createState() => _SafetyCreateSheetState();
}

class _SafetyCreateSheetState extends State<_SafetyCreateSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _address = TextEditingController();

  String _type = SafetyIncidentType.verdaechtig;
  bool _anonymous = false;
  bool _titleError = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = true);
      return;
    }
    setState(() => _saving = true);
    final report = SafetyReport(
      id: '',
      reporterId: null,
      title: title,
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      incidentType: _type,
      anonymous: _anonymous,
      status: 'active',
      locationAddress:
          _address.text.trim().isEmpty ? null : _address.text.trim(),
      locationLat: widget.position?.latitude,
      locationLng: widget.position?.longitude,
      happenedAt: DateTime.now().toUtc(),
    );
    final id = await SafetyRepository.create(report);
    if (!mounted) return;
    setState(() => _saving = false);
    if (id != null) {
      AppSnackBar.success(context, 'safety.submitted'.tr());
      Navigator.of(context).pop(true);
    } else {
      AppSnackBar.error(context, 'safety.submitError'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),
            Text('safety.createTitle'.tr(),
                style: AppTypography.display(size: 18, color: AppColors.ink)),
            const SizedBox(height: 16),
            // Typ-Auswahl (Farbkodierung)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in SafetyIncidentType.all)
                  _TypeChip(
                    type: t,
                    selected: _type == t,
                    onTap: () => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 120,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              onChanged: _titleError
                  ? (_) => setState(() => _titleError = false)
                  : null,
              decoration: InputDecoration(
                labelText: 'safety.fieldTitle'.tr(),
                errorText: _titleError ? 'safety.titleRequired'.tr() : null,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLines: 4,
              maxLength: 1500,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'safety.fieldDescription'.tr(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'safety.fieldLocation'.tr(),
                helperText: widget.position == null
                    ? 'safety.locationHint'.tr()
                    : 'safety.locationAttached'.tr(),
                helperStyle: AppTypography.caption(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              activeColor: AppColors.herzrot,
              onChanged: (v) => setState(() => _anonymous = v),
              title: Text('safety.anonymous'.tr(),
                  style:
                      AppTypography.body(size: 14, color: AppColors.ink)),
              subtitle: Text('safety.anonymousHint'.tr(),
                  style: AppTypography.caption()),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.herzrot,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.ink),
                      )
                    : const Icon(LucideIcons.send, size: 18),
                label: Text('safety.submit'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _SafetyScreenState.colorFor(type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.20)
              : AppColors.elevated,
          border: Border.all(
            color: selected ? color : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_SafetyScreenState.iconFor(type),
                size: 14, color: selected ? color : AppColors.inkSoft),
            const SizedBox(width: 6),
            Text(
              _SafetyScreenState.labelFor(type),
              style: AppTypography.label(
                size: 10,
                color: selected ? color : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
