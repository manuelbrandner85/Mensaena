import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features (Admin Phase 5)
/// Generischer Tabellen-Browser: 100 letzte Rows der Supabase-Tabelle,
/// mit Volltext-Suche ueber alle Felder. Auswahl oeffnet JSON-Sheet.
class AdminTableScreen extends ConsumerStatefulWidget {
  const AdminTableScreen({
    required this.title,
    required this.tableName,
    required this.currentRoute,
    this.orderBy = 'created_at',
    this.titleField = 'title',
    this.subtitleFields = const ['name', 'email', 'display_name', 'category'],
    super.key,
  });

  final String title;
  final String tableName;
  final String currentRoute;
  final String orderBy;
  final String titleField;
  final List<String> subtitleFields;

  @override
  ConsumerState<AdminTableScreen> createState() => _AdminTableScreenState();
}

class _AdminTableScreenState extends ConsumerState<AdminTableScreen> {
  Future<List<Map<String, dynamic>>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = AdminRepository.recent(
      widget.tableName,
      orderBy: widget.orderBy,
    );
  }

  Future<void> _refresh() async {
    final fresh = AdminRepository.recent(
      widget.tableName,
      orderBy: widget.orderBy,
    );
    setState(() => _future = fresh);
    await fresh;
  }

  String _titleOf(Map<String, dynamic> row) {
    final v = row[widget.titleField];
    if (v is String && v.isNotEmpty) return v;
    for (final f in widget.subtitleFields) {
      final s = row[f];
      if (s is String && s.isNotEmpty) return s;
    }
    return (row['id'] as String?) ?? '—';
  }

  String _subtitleOf(Map<String, dynamic> row) {
    final parts = <String>[];
    for (final f in widget.subtitleFields) {
      final v = row[f];
      if (v is String && v.isNotEmpty) parts.add(v);
    }
    if (parts.isEmpty) {
      final id = row['id'];
      if (id is String) parts.add(id.substring(0, 8));
    }
    return parts.join(' · ');
  }

  bool _matches(Map<String, dynamic> row) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return row.values
        .whereType<String>()
        .any((v) => v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Admin: ${widget.title}',
      currentRoute: widget.currentRoute,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.elevated,
                  prefixIcon: const Icon(LucideIcons.search,
                      size: 16, color: AppColors.mute),
                  hintText: 'Suchen in ${widget.tableName}…',
                  hintStyle: AppTypography.body(
                    size: 13,
                    color: AppColors.mute,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 0),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: _refresh,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.amber),
                      );
                    }
                    final rows =
                        (snap.data ?? const <Map<String, dynamic>>[])
                            .where(_matches)
                            .toList();
                    if (rows.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 120),
                          Center(
                            child: Text(
                              'Keine Einträge.',
                              style: AppTypography.body(
                                size: 13,
                                color: AppColors.mute,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        return _AdminRow(
                          title: _titleOf(row),
                          subtitle: _subtitleOf(row),
                          row: row,
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

class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.title,
    required this.subtitle,
    required this.row,
  });

  final String title;
  final String subtitle;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scroll) => ListView(
            controller: scroll,
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
              const SizedBox(height: 14),
              Text(title,
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink)),
              const SizedBox(height: 12),
              for (final entry in row.entries) ...[
                Text(entry.key, style: AppTypography.label(size: 9)),
                const SizedBox(height: 2),
                Text(
                  entry.value?.toString() ?? 'null',
                  style: AppTypography.mono(
                    size: 12,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                color: AppColors.mute, size: 16),
          ],
        ),
      ),
    );
  }
}
