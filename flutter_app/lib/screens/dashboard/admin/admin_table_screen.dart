import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../services/supabase_service.dart';
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
      title: 'admin.tableTitlePrefix'.tr(namedArgs: {'title': widget.title}),
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
                  hintText: 'admin.searchInTable'.tr(namedArgs: {'table': widget.tableName}),
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
                          tableName: widget.tableName,
                          onChanged: _refresh,
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
    required this.tableName,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final Map<String, dynamic> row;
  final String tableName;
  final VoidCallback onChanged;

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
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scroll) => _AdminDetailSheet(
            scroll: scroll,
            title: title,
            row: row,
            tableName: tableName,
            onChanged: onChanged,
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

// ── Detail-Sheet mit Aktionen (Delete, Status, Ban) ──────────────
class _AdminDetailSheet extends StatefulWidget {
  const _AdminDetailSheet({
    required this.scroll,
    required this.title,
    required this.row,
    required this.tableName,
    required this.onChanged,
  });

  final ScrollController scroll;
  final String title;
  final Map<String, dynamic> row;
  final String tableName;
  final VoidCallback onChanged;

  @override
  State<_AdminDetailSheet> createState() => _AdminDetailSheetState();
}

class _AdminDetailSheetState extends State<_AdminDetailSheet> {
  bool _busy = false;
  bool _editing = false;
  // Pro-Feld TextEditingControllers für editierbare String/Number-Felder.
  final Map<String, TextEditingController> _editCtrls = {};
  // Pro-Feld aktueller Boolean-Wert für Switch-Felder.
  final Map<String, bool> _editBools = {};

  // Felder die NIE editierbar sein sollen — würden FK-Constraints brechen
  // oder Audit-Spuren manipulieren.
  static const _readonlyFields = {
    'id', 'created_at', 'updated_at', 'auth_created_at',
    'profile_created_at', 'email_confirmed_at', 'last_sign_in_at',
    'deleted_at', 'banned_until', 'profile_missing',
  };

  bool _isReadonly(String key) {
    if (_readonlyFields.contains(key)) return true;
    // Alle Fremdschlüssel-IDs (user_id, helper_id, post_id, etc.)
    if (key.endsWith('_id')) return true;
    return false;
  }

  String? get _id => widget.row['id'] as String?;

  @override
  void dispose() {
    for (final c in _editCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _enterEditMode() {
    setState(() {
      _editing = true;
      _editCtrls.clear();
      _editBools.clear();
      for (final entry in widget.row.entries) {
        if (_isReadonly(entry.key)) continue;
        final v = entry.value;
        if (v is bool) {
          _editBools[entry.key] = v;
        } else if (v == null || v is String || v is num) {
          _editCtrls[entry.key] =
              TextEditingController(text: v?.toString() ?? '');
        }
        // Maps/Lists/JSONb übersprungen — Admin nutzt SQL-Editor für komplexe
        // Strukturen.
      }
    });
  }

  void _cancelEdit() {
    for (final c in _editCtrls.values) {
      c.dispose();
    }
    setState(() {
      _editing = false;
      _editCtrls.clear();
      _editBools.clear();
    });
  }

  Future<void> _saveEdit() async {
    if (_id == null) return;
    setState(() => _busy = true);
    var allOk = true;
    var changed = 0;
    try {
      for (final entry in _editCtrls.entries) {
        final original = widget.row[entry.key];
        final newText = entry.value.text.trim();
        // Empty + originaly null → no change
        final originalStr = original?.toString() ?? '';
        if (newText == originalStr) continue;
        // Number-Erkennung: wenn original num war, versuche zu parsen.
        dynamic newValue;
        if (newText.isEmpty) {
          newValue = null;
        } else if (original is int) {
          newValue = int.tryParse(newText) ?? newText;
        } else if (original is double) {
          newValue = double.tryParse(newText) ?? newText;
        } else {
          newValue = newText;
        }
        final ok = await AdminRepository.updateField(
          table: widget.tableName,
          id: _id!,
          column: entry.key,
          value: newValue,
        );
        if (!ok) allOk = false;
        if (ok) changed++;
      }
      for (final entry in _editBools.entries) {
        final original = widget.row[entry.key];
        if (original == entry.value) continue;
        final ok = await AdminRepository.updateField(
          table: widget.tableName,
          id: _id!,
          column: entry.key,
          value: entry.value,
        );
        if (!ok) allOk = false;
        if (ok) changed++;
      }
    } catch (_) {
      allOk = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (allOk && changed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.editSaved'.tr(
          namedArgs: {'n': '$changed'},
        ))),
      );
      widget.onChanged();
      Navigator.of(context).pop();
    } else if (changed == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.editNoChanges'.tr())),
      );
      _cancelEdit();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.editPartialFail'.tr(
          namedArgs: {'n': '$changed'},
        ))),
      );
      widget.onChanged();
    }
  }

  // Erlaubte Status-Werte je Tabelle (1:1 zu Web-Admin)
  List<String> get _availableStatuses {
    switch (widget.tableName) {
      case 'reports':
      case 'content_reports': // Legacy fallthrough, beide Stati identisch.
        return const ['pending', 'reviewed', 'resolved', 'dismissed'];
      case 'crisis_situations':
      case 'crises':
        return const ['active', 'resolved', 'archived'];
      case 'farm_listings':
      case 'organizations':
      case 'posts':
      case 'board_posts':
      case 'events':
        return const ['draft', 'published', 'archived'];
      case 'challenges':
        return const ['active', 'archived'];
      default:
        return const [];
    }
  }

  bool get _hasStatusField => widget.row.containsKey('status');

  bool get _isProfilesTable => widget.tableName == 'profiles';

  Future<void> _setStatus(String s) async {
    if (_id == null) return;
    setState(() => _busy = true);
    final ok = await AdminRepository.updateStatus(
      table: widget.tableName,
      id: _id!,
      status: s,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.statusSetTo'.tr(namedArgs: {'s': s}))),
      );
      widget.onChanged();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.statusUpdateFailed'.tr())),
      );
    }
  }

  Future<void> _setField(String column, dynamic value, String label) async {
    if (_id == null) return;
    setState(() => _busy = true);
    final ok = await AdminRepository.updateField(
      table: widget.tableName,
      id: _id!,
      column: column,
      value: value,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label gesetzt.')),
      );
      widget.onChanged();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.actionFailed'.tr())),
      );
    }
  }

  Future<void> _delete() async {
    if (_id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('admin.deleteConfirmTitle'.tr(),
            style: AppTypography.body(
                size: 16, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text(
          'admin.deleteEntryConfirm'
              .tr(namedArgs: {'table': widget.tableName}),
          style: AppTypography.body(size: 13, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final ok = await AdminRepository.delete(
      table: widget.tableName,
      id: _id!,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.entryDeleted'.tr())),
      );
      widget.onChanged();
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('admin.deleteFailed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = widget.row['status'] as String?;
    final isBanned = widget.row['is_banned'] == true;
    final isAdmin = widget.row['role'] == 'admin';
    // Self-Guard: keine Role-Toggle / Ban-Toggle auf eigenes Profil.
    final isSelf = widget.row['id'] == SupabaseService.currentUser?.id;
    return ListView(
      controller: widget.scroll,
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
        Text(widget.title,
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text('admin.tableName'.tr(namedArgs: {'name': widget.tableName}),
            style: AppTypography.label(size: 9, color: AppColors.mute)),
        const SizedBox(height: 14),

        // ── Aktionen ────────────────────────────────────────────
        if (_hasStatusField && _availableStatuses.isNotEmpty) ...[
          Text('admin.status'.tr(), style: AppTypography.label(size: 10)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in _availableStatuses)
                ChoiceChip(
                  label: Text(s),
                  selected: currentStatus == s,
                  onSelected: _busy ? null : (_) => _setStatus(s),
                  backgroundColor: AppColors.elevated,
                  selectedColor: AppColors.bronze.withValues(alpha: 0.4),
                  labelStyle: AppTypography.body(
                    size: 11,
                    color: currentStatus == s
                        ? AppColors.bronze
                        : AppColors.inkSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // ── Profile-spezifisch (Ban/Admin-Toggle) ───────────────
        if (_isProfilesTable) ...[
          Text('admin.profileActions'.tr(), style: AppTypography.label(size: 10)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _setField('is_banned', !isBanned,
                        isBanned ? 'Entsperrt' : 'Gesperrt'),
                icon: Icon(
                    isBanned ? LucideIcons.unlock : LucideIcons.ban,
                    size: 14),
                label: Text(isBanned ? 'Entsperren' : 'Sperren'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBanned
                      ? AppColors.leben.withValues(alpha: 0.2)
                      : AppColors.herzrot.withValues(alpha: 0.2),
                  foregroundColor:
                      isBanned ? AppColors.lebenSoft : AppColors.herzrotWarm,
                  elevation: 0,
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_busy || isSelf)
                    ? null
                    : () => _setField(
                          'role',
                          isAdmin ? 'user' : 'admin',
                          isAdmin ? 'Admin entzogen' : 'Admin-Rechte vergeben',
                        ),
                icon: Icon(
                    isAdmin
                        ? LucideIcons.shieldOff
                        : LucideIcons.shieldCheck,
                    size: 14),
                label: Text(isAdmin ? 'Admin entziehen' : 'Zum Admin machen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.bronze.withValues(alpha: 0.2),
                  foregroundColor: AppColors.bronze,
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // ── Edit + Delete ───────────────────────────────────────
        if (!_editing) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || _id == null ? null : _enterEditMode,
                  icon: const Icon(LucideIcons.pencil, size: 14),
                  label: Text('admin.editEntry'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bronze,
                    side: BorderSide(
                        color: AppColors.bronze.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || _id == null ? null : _delete,
                  icon: const Icon(LucideIcons.trash2, size: 14),
                  label: Text('admin.deleteEntry'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.herzrot,
                    side: BorderSide(
                        color: AppColors.herzrot.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _saveEdit,
                  icon: const Icon(LucideIcons.check, size: 14),
                  label: Text('common.save'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _cancelEdit,
                  icon: const Icon(LucideIcons.x, size: 14),
                  label: Text('common.cancel'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mute,
                    side: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // ── Daten (Roh oder Edit-Form) ─────────────────────────
        Text(
          _editing ? 'admin.editFields'.tr() : 'admin.rawData'.tr(),
          style: AppTypography.label(size: 10),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in widget.row.entries) ...[
                Text(entry.key, style: AppTypography.label(size: 9)),
                const SizedBox(height: 4),
                _renderField(entry.key, entry.value),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _renderField(String key, dynamic value) {
    if (!_editing || _isReadonly(key)) {
      return Text(
        value?.toString() ?? 'null',
        style: AppTypography.mono(size: 11, color: AppColors.inkSoft),
      );
    }
    if (value is bool || _editBools.containsKey(key)) {
      return Row(
        children: [
          Switch(
            value: _editBools[key] ?? (value is bool ? value : false),
            activeColor: AppColors.bronze,
            onChanged: _busy
                ? null
                : (v) => setState(() => _editBools[key] = v),
          ),
          const SizedBox(width: 8),
          Text(
            (_editBools[key] ?? false) ? 'true' : 'false',
            style: AppTypography.mono(size: 11, color: AppColors.inkSoft),
          ),
        ],
      );
    }
    final ctrl = _editCtrls[key];
    if (ctrl == null) {
      // Komplexes Feld (Map/List) — nicht editierbar im generischen UI.
      return Text(
        value?.toString() ?? 'null',
        style: AppTypography.mono(size: 11, color: AppColors.mute),
      );
    }
    final isNumber = value is num;
    final isMultiline = (value is String) && value.length > 60;
    return TextField(
      controller: ctrl,
      enabled: !_busy,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : (isMultiline ? TextInputType.multiline : TextInputType.text),
      maxLines: isMultiline ? null : 1,
      minLines: isMultiline ? 2 : 1,
      style: AppTypography.mono(size: 12, color: AppColors.ink),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.bronze),
        ),
      ),
    );
  }
}
