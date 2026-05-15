import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_badge.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_modal.dart';
import '../../core/widgets/cinema_select.dart';
import '../../core/widgets/cinema_stat.dart';
import '../../core/widgets/cinema_tabs.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase/database_service.dart';
import '../../services/supabase/supabase_service.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  static const _labels = [
    'Uebersicht',
    'Users',
    'Posts',
    'Events',
    'Board',
    'Krise',
    'Orgs',
    'Hoefe',
    'Chat-Mod',
    'System',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _labels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).asData?.value;
    final isAdmin = profile?['is_admin'] == true;

    if (!isAdmin) {
      // Redirect zu Dashboard bei Nicht-Admins.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) GoRouter.of(context).go('/dashboard');
      });
      return const CinemaScaffold(body: SizedBox.shrink());
    }

    return CinemaScaffold(
      level: AtmosphereLevel.focus,
      appBar: const CinemaAppBar(title: 'ADMIN'),
      body: SafeArea(
        child: Column(
          children: [
            CinemaTabs(controller: _tabs, labels: _labels),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _OverviewTab(),
                  _SimpleListTab(table: 'profiles', label: 'Profile'),
                  _SimpleListTab(table: 'posts', label: 'Posts'),
                  _SimpleListTab(table: 'events', label: 'Events'),
                  _SimpleListTab(table: 'board_posts', label: 'Board'),
                  _CrisisTab(),
                  _SimpleListTab(table: 'organizations', label: 'Organisationen'),
                  _SimpleListTab(table: 'farm_listings', label: 'Bauernhoefe'),
                  _SimpleListTab(table: 'content_reports', label: 'Reports'),
                  _SystemTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _adminStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final tables = [
    'profiles',
    'posts',
    'events',
    'conversations',
    'messages',
    'notifications',
    'content_reports',
    'crises',
  ];
  final result = <String, int>{};
  for (final t in tables) {
    try {
      final res = await supabase.client.from(t).select('id');
      result[t] = (res as List).length;
    } catch (_) {
      result[t] = 0;
    }
  }
  return result;
});

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_adminStatsProvider);
    return stats.when(
      loading: () => const CinemaLoadingSkeleton(),
      error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
      data: (s) => GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          CinemaStat(value: s['profiles'] ?? 0, label: 'Profile', icon: LucideIcons.users),
          CinemaStat(value: s['posts'] ?? 0, label: 'Posts', icon: LucideIcons.fileText),
          CinemaStat(value: s['events'] ?? 0, label: 'Events', icon: LucideIcons.calendar),
          CinemaStat(value: s['conversations'] ?? 0, label: 'Conversations', icon: LucideIcons.messageCircle),
          CinemaStat(value: s['messages'] ?? 0, label: 'Messages', icon: LucideIcons.send),
          CinemaStat(value: s['notifications'] ?? 0, label: 'Notifications', icon: LucideIcons.bell),
          CinemaStat(
            value: s['content_reports'] ?? 0,
            label: 'Reports',
            icon: LucideIcons.alertTriangle,
            valueColor: MnColors.herzrot,
          ),
          CinemaStat(
            value: s['crises'] ?? 0,
            label: 'Krisen aktiv',
            icon: LucideIcons.alertCircle,
            valueColor: MnColors.herzrot,
          ),
        ],
      ),
    );
  }
}

class _SimpleListTab extends ConsumerWidget {
  final String table;
  final String label;
  const _SimpleListTab({required this.table, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_tableProvider(table));
    return data.when(
      loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
      error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
      data: (rows) {
        if (rows.isEmpty) {
          return CinemaEmptyState(
            icon: LucideIcons.database,
            title: 'Keine Eintraege in $label.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final r = rows[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MnColors.elevated,
                borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                border: Border.all(color: MnColors.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (r['title'] as String?) ??
                              (r['full_name'] as String?) ??
                              (r['name'] as String?) ??
                              (r['id'] as String?) ??
                              '',
                          style: MnTypography.body(weight: FontWeight.w600),
                        ),
                        if (r['created_at'] != null)
                          Text(
                            r['created_at'].toString(),
                            style: MnTypography.mono(size: 11, color: MnColors.mute),
                          ),
                        if (table == 'content_reports' &&
                            r['status'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: CinemaBadge(
                              label: (r['status'] as String?) ?? '—',
                              variant: _statusBadge(r['status'] as String?),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _RowActions(table: table, row: r),
                ],
              ),
            );
          },
        );
      },
    );
  }

  BadgeVariant _statusBadge(String? s) {
    switch (s) {
      case 'resolved':
        return BadgeVariant.leben;
      case 'rejected':
        return BadgeVariant.mute;
      default:
        return BadgeVariant.herzrot;
    }
  }
}

final _tableProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, table) async {
  final res = await supabase.client
      .from(table)
      .select()
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(res as List);
});

/// Trailing-Aktionen je nach Tabelle.
class _RowActions extends ConsumerWidget {
  final String table;
  final Map<String, dynamic> row;
  const _RowActions({required this.table, required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (table) {
      case 'profiles':
        return _UserActions(row: row);
      case 'content_reports':
        return _ReportActions(row: row);
      case 'board_posts':
        return _BoardActions(row: row);
      case 'events':
        return _EventActions(row: row);
      case 'posts':
      case 'organizations':
      case 'farm_listings':
        return _DeleteAction(table: table, row: row);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _DeleteAction extends ConsumerWidget {
  final String table;
  final Map<String, dynamic> row;
  const _DeleteAction({required this.table, required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Loeschen',
      icon: const Icon(LucideIcons.trash2, size: 18, color: MnColors.herzrot),
      onPressed: () => _confirmDelete(context, ref, table, row),
    );
  }
}

class _EventActions extends ConsumerWidget {
  final Map<String, dynamic> row;
  const _EventActions({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Bearbeiten',
          icon: const Icon(LucideIcons.pencil, size: 18, color: MnColors.amber),
          onPressed: () {
            final id = row['id'] as String?;
            if (id != null) {
              GoRouter.of(context).push('/dashboard/events/$id');
            }
          },
        ),
        IconButton(
          tooltip: 'Loeschen',
          icon: const Icon(LucideIcons.trash2, size: 18, color: MnColors.herzrot),
          onPressed: () => _confirmDelete(context, ref, 'events', row),
        ),
      ],
    );
  }
}

class _BoardActions extends ConsumerWidget {
  final Map<String, dynamic> row;
  const _BoardActions({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Pin/Unpin',
          icon: const Icon(LucideIcons.pin, size: 18, color: MnColors.teal),
          onPressed: () async {
            final id = row['id'] as String?;
            if (id == null) return;
            try {
              await db.toggleBoardPin(id);
              if (!context.mounted) return;
              CinemaToast.show(
                context,
                variant: ToastVariant.success,
                message: 'Pin-Status aktualisiert.',
              );
              ref.invalidate(_tableProvider);
            } catch (e) {
              if (!context.mounted) return;
              CinemaToast.show(
                context,
                variant: ToastVariant.error,
                message: 'Fehler: $e',
              );
            }
          },
        ),
        IconButton(
          tooltip: 'Loeschen',
          icon: const Icon(LucideIcons.trash2, size: 18, color: MnColors.herzrot),
          onPressed: () => _confirmDelete(context, ref, 'board_posts', row),
        ),
      ],
    );
  }
}

class _UserActions extends ConsumerWidget {
  final Map<String, dynamic> row;
  const _UserActions({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banned = row['banned'] == true;
    return IconButton(
      tooltip: banned ? 'Entsperren' : 'Sperren',
      icon: Icon(
        banned ? LucideIcons.unlock : LucideIcons.lock,
        size: 18,
        color: banned ? MnColors.leben : MnColors.herzrot,
      ),
      onPressed: () async {
        final id = row['id'] as String?;
        if (id == null) return;
        if (banned) {
          try {
            await db.setUserBanned(id, banned: false);
            if (!context.mounted) return;
            CinemaToast.show(
              context,
              variant: ToastVariant.success,
              message: 'User entsperrt.',
            );
            ref.invalidate(_tableProvider);
          } catch (e) {
            if (!context.mounted) return;
            CinemaToast.show(
              context,
              variant: ToastVariant.error,
              message: 'Fehler: $e',
            );
          }
          return;
        }

        final reasonCtrl = TextEditingController();
        final confirm = await CinemaModal.show<bool>(
          context,
          title: 'User sperren?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (row['full_name'] as String?) ?? id,
                style: MnTypography.body(weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              CinemaInput(
                controller: reasonCtrl,
                label: 'Grund',
                placeholder: 'z.B. wiederholte Verstoesse',
                variant: CinemaInputVariant.multiline,
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            GlowButton(
              label: 'Abbrechen',
              variant: GlowVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            GlowButton(
              label: 'Sperren',
              variant: GlowVariant.crisis,
              icon: LucideIcons.lock,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
        if (confirm != true || !context.mounted) return;
        try {
          await db.setUserBanned(
            id,
            banned: true,
            reason: reasonCtrl.text.trim(),
          );
          if (!context.mounted) return;
          CinemaToast.show(
            context,
            variant: ToastVariant.success,
            message: 'User gesperrt.',
          );
          ref.invalidate(_tableProvider);
        } catch (e) {
          if (!context.mounted) return;
          CinemaToast.show(
            context,
            variant: ToastVariant.error,
            message: 'Fehler: $e',
          );
        }
      },
    );
  }
}

class _ReportActions extends ConsumerWidget {
  final Map<String, dynamic> row;
  const _ReportActions({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Details',
          icon: const Icon(LucideIcons.eye, size: 18, color: MnColors.teal),
          onPressed: () => _showReportDetail(context, row),
        ),
        IconButton(
          tooltip: 'Aufloesen',
          icon: const Icon(LucideIcons.check, size: 18, color: MnColors.leben),
          onPressed: () => _setReport(context, ref, row, 'resolved'),
        ),
        IconButton(
          tooltip: 'Abweisen',
          icon: const Icon(LucideIcons.x, size: 18, color: MnColors.herzrot),
          onPressed: () => _setReport(context, ref, row, 'rejected'),
        ),
      ],
    );
  }
}

void _showReportDetail(BuildContext context, Map<String, dynamic> row) {
  CinemaModal.show<void>(
    context,
    title: 'Report Details',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _detailRow('Reporter', (row['reporter_id'] as String?) ?? '—'),
        _detailRow('Ziel', (row['target_id'] as String?) ?? '—'),
        _detailRow('Typ', (row['target_type'] as String?) ?? '—'),
        _detailRow('Grund', (row['reason'] as String?) ?? '—'),
        _detailRow(
          'Beschreibung',
          (row['description'] as String?) ?? '—',
        ),
        _detailRow('Status', (row['status'] as String?) ?? '—'),
        _detailRow('Erstellt', (row['created_at'] as String?) ?? '—'),
      ],
    ),
    actions: [
      GlowButton(
        label: 'Schliessen',
        variant: GlowVariant.ghost,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MnTypography.label(color: MnColors.mute)),
        const SizedBox(height: 2),
        Text(value, style: MnTypography.body(color: MnColors.ink)),
      ],
    ),
  );
}

Future<void> _setReport(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> row,
  String status,
) async {
  final id = row['id'] as String?;
  if (id == null) return;
  try {
    await db.setReportStatus(id, status);
    if (!context.mounted) return;
    CinemaToast.show(
      context,
      variant: status == 'resolved'
          ? ToastVariant.success
          : ToastVariant.info,
      message: status == 'resolved'
          ? 'Report aufgeloest.'
          : 'Report abgewiesen.',
    );
    ref.invalidate(_tableProvider);
  } catch (e) {
    if (!context.mounted) return;
    CinemaToast.show(
      context,
      variant: ToastVariant.error,
      message: 'Fehler: $e',
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  String table,
  Map<String, dynamic> row,
) async {
  final id = row['id'] as String?;
  if (id == null) return;
  final title = (row['title'] as String?) ??
      (row['name'] as String?) ??
      (row['full_name'] as String?) ??
      id;

  final confirm = await CinemaModal.show<bool>(
    context,
    title: 'Wirklich loeschen?',
    child: Text(
      'Eintrag "$title" wird unwiderruflich aus $table geloescht.',
      style: MnTypography.body(color: MnColors.inkSoft),
    ),
    actions: [
      GlowButton(
        label: 'Abbrechen',
        variant: GlowVariant.ghost,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      GlowButton(
        label: 'Loeschen',
        variant: GlowVariant.crisis,
        icon: LucideIcons.trash2,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  if (confirm != true || !context.mounted) return;
  try {
    await db.adminDeleteRow(table, id);
    if (!context.mounted) return;
    CinemaToast.show(
      context,
      variant: ToastVariant.success,
      message: 'Geloescht.',
    );
    ref.invalidate(_tableProvider);
    ref.invalidate(_adminStatsProvider);
  } catch (e) {
    if (!context.mounted) return;
    CinemaToast.show(
      context,
      variant: ToastVariant.error,
      message: 'Fehler beim Loeschen: $e',
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// CRISIS TAB
// ───────────────────────────────────────────────────────────────────────

final _crisisStatsProvider = FutureProvider<Map<String, int>>((ref) {
  return db.getCrisisStats();
});

class _CrisisTab extends ConsumerWidget {
  const _CrisisTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crises = ref.watch(_tableProvider('crises'));
    final stats = ref.watch(_crisisStatsProvider);

    return Container(
      color: MnColors.herzrotDeep.withValues(alpha: 0.08),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          stats.when(
            loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.text),
            error: (e, _) => Text('$e', style: MnTypography.body()),
            data: (s) => SizedBox(
              height: 120,
              child: Row(
                children: [
                  Expanded(
                    child: CinemaStat(
                      value: s['active'] ?? 0,
                      label: 'Aktive Krisen',
                      icon: LucideIcons.alertCircle,
                      valueColor: MnColors.herzrot,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CinemaStat(
                      value: s['posts'] ?? 0,
                      label: 'Krisenbeitraege (7T)',
                      icon: LucideIcons.fileText,
                      valueColor: MnColors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CinemaStat(
                      value: s['helpers'] ?? 0,
                      label: 'Helfende',
                      icon: LucideIcons.users,
                      valueColor: MnColors.leben,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlowButton(
            label: 'Krisenmodus aktivieren',
            variant: GlowVariant.crisis,
            fullWidth: true,
            icon: LucideIcons.alertTriangle,
            onPressed: () => _openActivationModal(context, ref),
          ),
          const SizedBox(height: 16),
          crises.when(
            loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.text),
            error: (e, _) => Text('$e', style: MnTypography.body()),
            data: (rows) => Column(
              children: rows.map((r) {
                final active = r['active'] == true;
                final id = r['id'] as String?;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MnColors.elevated,
                    borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (r['type'] as String?) ?? 'Krise',
                              style: MnTypography.body(weight: FontWeight.w600),
                            ),
                            Text(
                              (r['description'] as String?) ?? '',
                              style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      CinemaBadge(
                        label: active ? 'aktiv' : 'beendet',
                        variant: active ? BadgeVariant.herzrot : BadgeVariant.mute,
                      ),
                      const SizedBox(width: 8),
                      if (active && id != null)
                        GlowButton(
                          label: 'Deaktivieren',
                          variant: GlowVariant.ghost,
                          compact: true,
                          onPressed: () async {
                            try {
                              await db.deactivateCrisis(id);
                              if (!context.mounted) return;
                              CinemaToast.show(
                                context,
                                variant: ToastVariant.success,
                                message: 'Krise deaktiviert.',
                              );
                              ref.invalidate(_tableProvider);
                              ref.invalidate(_crisisStatsProvider);
                              ref.invalidate(_adminStatsProvider);
                            } catch (e) {
                              if (!context.mounted) return;
                              CinemaToast.show(
                                context,
                                variant: ToastVariant.error,
                                message: 'Fehler: $e',
                              );
                            }
                          },
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openActivationModal(BuildContext context, WidgetRef ref) async {
  final userId = ref.read(currentUserProvider)?.id;
  if (userId == null) {
    CinemaToast.show(
      context,
      variant: ToastVariant.error,
      message: 'Nicht eingeloggt.',
    );
    return;
  }

  final formState = _CrisisForm();
  final regionCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String? descError;

  await CinemaModal.show<void>(
    context,
    title: 'Krisenmodus aktivieren',
    child: StatefulBuilder(
      builder: (ctx, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            CinemaSelect<String>(
              label: 'Typ',
              value: formState.type,
              options: const [
                CinemaSelectOption(value: 'hochwasser', label: 'Hochwasser'),
                CinemaSelectOption(value: 'sturm', label: 'Sturm'),
                CinemaSelectOption(value: 'erdbeben', label: 'Erdbeben'),
                CinemaSelectOption(value: 'stromausfall', label: 'Stromausfall'),
                CinemaSelectOption(value: 'brand', label: 'Brand'),
                CinemaSelectOption(value: 'sonstige', label: 'Sonstige'),
              ],
              onChanged: (v) => setState(() => formState.type = v),
            ),
            const SizedBox(height: 12),
            CinemaInput(
              controller: regionCtrl,
              label: 'Region (optional)',
              placeholder: 'z.B. Linz, Oberoesterreich',
            ),
            const SizedBox(height: 12),
            CinemaInput(
              controller: descCtrl,
              label: 'Beschreibung *',
              placeholder: 'Was ist passiert? Welche Hilfe wird gebraucht?',
              variant: CinemaInputVariant.multiline,
              maxLines: 5,
              errorText: descError,
            ),
            const SizedBox(height: 16),
            GlowButton(
              label: 'Aktivieren',
              variant: GlowVariant.crisis,
              fullWidth: true,
              icon: LucideIcons.alertTriangle,
              onPressed: () async {
                if (formState.type == null) {
                  CinemaToast.show(
                    ctx,
                    variant: ToastVariant.warning,
                    message: 'Bitte Typ waehlen.',
                  );
                  return;
                }
                final desc = descCtrl.text.trim();
                if (desc.isEmpty) {
                  setState(() => descError = 'Beschreibung erforderlich');
                  return;
                }
                try {
                  await db.activateCrisis(
                    type: formState.type!,
                    description: desc,
                    region: regionCtrl.text.trim(),
                    activatedBy: userId,
                  );
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  CinemaToast.show(
                    context,
                    variant: ToastVariant.success,
                    message: 'Krisenmodus aktiviert.',
                  );
                  ref.invalidate(_tableProvider);
                  ref.invalidate(_crisisStatsProvider);
                  ref.invalidate(_adminStatsProvider);
                } catch (e) {
                  if (!ctx.mounted) return;
                  CinemaToast.show(
                    ctx,
                    variant: ToastVariant.error,
                    message: 'Fehler: $e',
                  );
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

class _CrisisForm {
  String? type;
}

class _SystemTab extends StatelessWidget {
  const _SystemTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('System-Status', style: MnTypography.display(size: 20)),
        const SizedBox(height: 16),
        Text(
          'Supabase Project: huaqldjkgyosefzfhjnf',
          style: MnTypography.mono(size: 12, color: MnColors.mute),
        ),
        const SizedBox(height: 8),
        Text(
          'Storage Buckets: avatars, post-images, chat-media, board-images, '
          'event-images, marketplace, wiki-images, group-images',
          style: MnTypography.body(color: MnColors.inkSoft, size: 13),
        ),
        const SizedBox(height: 8),
        Text(
          'RLS-Policies: aktiv auf allen 37+ Tabellen.',
          style: MnTypography.body(color: MnColors.inkSoft, size: 13),
        ),
      ],
    );
  }
}
