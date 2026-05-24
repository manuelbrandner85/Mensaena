import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/skeleton_card.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/module_search_bar.dart';

/// SKILL: mensaena-features (Admin Phase 5)
/// 1:1 zu `src/app/dashboard/admin/components/ReportsTab.tsx`.
/// Liste von content_reports mit Status-Filter, Suche, Inline-Aktionen
/// (Reviewed/Resolved/Dismissed/Delete).
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() =>
      _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  static const List<FilterOption<String>> _statuses = [
    FilterOption(value: 'pending', label: '⏳ Ausstehend'),
    FilterOption(value: 'reviewed', label: '👁️ Geprüft'),
    FilterOption(value: 'resolved', label: '✅ Gelöst'),
    FilterOption(value: 'dismissed', label: '🚫 Abgelehnt'),
  ];

  String? _status;
  String _search = '';
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = AdminRepository.recent(
        'content_reports',
        statusFilter: _status,
      );
    });
  }

  Future<void> _setStatus(String id, String status) async {
    final ok = await AdminRepository.updateStatus(
      table: 'content_reports',
      id: id,
      status: status,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok ? 'Status: $status' : 'Fehler beim Update.',
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
    if (ok) _load();
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('admin.deleteReportTitle'.tr(),
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        content: Text('admin.deleteReportConfirm'.tr(),
            style: AppTypography.body(size: 14, color: AppColors.inkSoft)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.herzrot),
            onPressed: () => Navigator.pop(context, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await AdminRepository.delete(table: 'content_reports', id: id);
    if (!mounted) return;
    if (ok) _load();
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((r) {
      return r.values
          .whereType<String>()
          .any((v) => v.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'admin.reportsTitle'.tr(),
      currentRoute: '/dashboard/admin/chat-moderation',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: ModuleSearchBar(
                hintText: 'admin.searchReason'.tr(),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: FilterChipBar<String>(
                options: _statuses,
                selected: _status == null ? const <String>{} : {_status!},
                onChanged: (s) {
                  setState(() => _status = s.isEmpty ? null : s.first);
                  _load();
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: () async => _load(),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const SkeletonList(count: 5, itemHeight: 96);
                    }
                    final rows = _apply(snap.data ?? const []);
                    if (rows.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 60),
                          EmptyStateCard(
                            icon: LucideIcons.flag,
                            title: 'admin.noReports'.tr(),
                            description: 'admin.tryOtherFilters'.tr(),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final r = rows[i];
                        return _ReportTile(
                          row: r,
                          onSetStatus: (s) =>
                              _setStatus(r['id'] as String, s),
                          onDelete: () => _delete(r['id'] as String),
                        );
                      },
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
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.row,
    required this.onSetStatus,
    required this.onDelete,
  });

  final Map<String, dynamic> row;
  final ValueChanged<String> onSetStatus;
  final VoidCallback onDelete;

  Color _statusColor(String s) {
    switch (s) {
      case 'resolved':
        return AppColors.leben;
      case 'dismissed':
        return AppColors.mute;
      case 'reviewed':
        return AppColors.tealSoft;
      default:
        return AppColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reason = row['reason'] as String? ?? '—';
    final type = row['content_type'] as String? ?? '—';
    final status = row['status'] as String? ?? 'pending';
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(999),
                ),
                child:
                    Text(type, style: AppTypography.label(size: 8)),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(status.toUpperCase(),
                    style: AppTypography.label(size: 8, color: color)),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(DateFormat('dd.MM. HH:mm').format(createdAt),
                    style: AppTypography.caption()),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: AppTypography.body(
              size: 14,
              color: AppColors.ink,
              weight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionPill(
                icon: LucideIcons.eye,
                label: 'Geprüft',
                color: AppColors.tealSoft,
                onTap: () => onSetStatus('reviewed'),
              ),
              _ActionPill(
                icon: LucideIcons.check,
                label: 'Gelöst',
                color: AppColors.leben,
                onTap: () => onSetStatus('resolved'),
              ),
              _ActionPill(
                icon: LucideIcons.x,
                label: 'Abgelehnt',
                color: AppColors.mute,
                onTap: () => onSetStatus('dismissed'),
              ),
              _ActionPill(
                icon: LucideIcons.trash2,
                label: 'Löschen',
                color: AppColors.herzrot,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.label(size: 9, color: color)),
          ],
        ),
      ),
    );
  }
}
