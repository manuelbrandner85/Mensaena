import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/module_search_bar.dart';

/// SKILL: mensaena-features (Admin Phase 5)
/// Nutzerverwaltung — Pagination, Rollen-Filter, Edit-Sheet, Ban-Dialog,
/// Delete-Confirm, Self-Role-Permission-Guard.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _search = '';
  String? _roleFilter; // null = all roles
  int _page = 0;
  static const int _pageSize = 20;

  List<Map<String, dynamic>> _users = const [];
  int _total = 0;
  bool _loading = true;

  Timer? _searchDebounce;

  // Edit-state
  Map<String, dynamic>? _editUser;
  final TextEditingController _editNameCtrl = TextEditingController();
  final TextEditingController _editNicknameCtrl = TextEditingController();
  String _editRole = 'user';
  bool _editSaving = false;

  // Self-Role for permission guard
  String? _myRole;
  bool _exporting = false;

  // A3 Bulk-Aktionen
  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// Wendet eine Bulk-Aktion auf alle ausgewählten Nutzer an (außer dem
  /// eigenen Konto). Sammelt Erfolge, zeigt Snackbar, lädt neu.
  bool _bulkBusy = false;

  Future<void> _applyBulk(
      Future<bool> Function(String id) action, String labelKey) async {
    // Guard: verhindert paralleles Auslösen während ein Batch (ggf. über 100
    // Nutzer) noch läuft → keine Doppel-Operationen.
    if (_bulkBusy) return;
    final myId = SupabaseService.currentUser?.id;
    final ids = _selectedIds.where((id) => id != myId).toList();
    if (ids.isEmpty) return;
    setState(() => _bulkBusy = true);
    var ok = 0;
    try {
      for (final id in ids) {
        if (await action(id)) ok++;
      }
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('admin.bulkDone'.tr(
            namedArgs: {'ok': '$ok', 'total': '${ids.length}'})),
      ),
    );
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
    _load();
  }

  Future<void> _bulkRole() async {
    final role = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in const ['user', 'moderator', 'admin'])
              ListTile(
                leading: const Icon(LucideIcons.shieldCheck,
                    color: AppColors.bronze),
                title: Text(r),
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (role == null) return;
    await _applyBulk(
        (id) => AdminRepository.changeUserRole(id, role), 'role');
  }

  /// A4: exportiert ALLE Nutzer (über die aktuelle Filter-Suche hinweg)
  /// als CSV und teilt sie via System-Share-Sheet. Holt bis zu 5000 Rows
  /// direkt aus admin_list_users — unabhängig von der Seiten-Pagination.
  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final rows = await AdminRepository.listUsersViaRpc(
        search: _search.isEmpty ? null : _search,
        role: _roleFilter,
        limit: 5000,
        offset: 0,
      );
      String esc(Object? v) {
        final s = (v ?? '').toString().replaceAll('"', '""');
        return '"$s"';
      }

      final buf = StringBuffer()
        ..writeln('id,email,name,nickname,role,verified_email,banned,'
            'trust_score,home_city,created_at,last_sign_in_at');
      for (final u in rows) {
        final verified = u['email_confirmed_at'] != null ||
            u['verified_email'] == true;
        buf.writeln([
          esc(u['id']),
          esc(u['email']),
          esc(u['display_name'] ?? u['name']),
          esc(u['nickname']),
          esc(u['role']),
          esc(verified),
          esc(u['is_banned'] == true),
          esc(u['trust_score']),
          esc(u['home_city']),
          esc(u['profile_created_at'] ?? u['created_at']),
          esc(u['last_sign_in_at']),
        ].join(','));
      }
      final dir = await getTemporaryDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '${dir.path}/mensaena_users_$ts.csv';
      await File(path).writeAsString(buf.toString());
      await Share.shareXFiles([XFile(path)],
          text: 'admin.exportCsvSubject'.tr());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('admin.exportCsvFailed'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMyRole();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _editNameCtrl.dispose();
    _editNicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyRole() async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final row = await sb
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _myRole = row?['role'] as String?);
    } catch (_) {
      // ignore; default guard = restrictive
    }
  }

  bool get _isAdmin => _myRole == 'admin';
  bool get _isModerator => _myRole == 'moderator' || _isAdmin;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Server-side Pagination: lade nur die aktuelle Seite via offset+limit.
      // Search + Role-Filter laufen ebenfalls im RPC — verhindert dass User
      // 101+ versteckt bleiben.
      final total = await AdminRepository.countUsersViaRpc(
        search: _search,
        role: _roleFilter,
      );
      // Falls aktuelle Seite jenseits des Totals liegt → auf Seite 0 springen.
      var page = _page;
      if (page * _pageSize >= total && total > 0) {
        page = 0;
      }
      final page0Users = await AdminRepository.listUsersViaRpc(
        search: _search,
        role: _roleFilter,
        limit: _pageSize,
        offset: page * _pageSize,
      );
      _total = total;
      _users = page0Users;
      _page = page;
    } catch (_) {
      _users = const [];
      _total = 0;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _search = v;
        _page = 0;
      });
      _load();
    });
  }

  void _setRoleFilter(String? v) {
    setState(() {
      _roleFilter = v;
      _page = 0;
    });
    _load();
  }

  // ---------------- Edit ----------------

  void _openEdit(Map<String, dynamic> user) {
    setState(() {
      _editUser = user;
      // Fallback-Kette: name → display_name → '' damit das Feld bei
      // bestehenden Usern nicht leer ist (sonst würde der Admin den Namen
      // versehentlich überschreiben wollen).
      _editNameCtrl.text = (user['name'] ??
              user['display_name'] ??
              '')
          .toString();
      _editNicknameCtrl.text = (user['nickname'] ?? '').toString();
      _editRole = (user['role'] ?? 'user').toString();
      _editSaving = false;
    });

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'admin.users.editTitle'.tr(),
                    style: AppTypography.display(size: 18),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _editNameCtrl,
                    style: AppTypography.body(size: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      labelText: 'admin.users.name'.tr(),
                      labelStyle: AppTypography.caption(),
                      filled: true,
                      fillColor: AppColors.elevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _editNicknameCtrl,
                    style: AppTypography.body(size: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      labelText: 'admin.users.nickname'.tr(),
                      labelStyle: AppTypography.caption(),
                      filled: true,
                      fillColor: AppColors.elevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: DropdownButton<String>(
                      value: _editRole,
                      isExpanded: true,
                      dropdownColor: AppColors.elevated,
                      underline: const SizedBox.shrink(),
                      style:
                          AppTypography.body(size: 14, color: AppColors.ink),
                      items: [
                        DropdownMenuItem(
                          value: 'user',
                          child: Text('admin.users.roleUser'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'moderator',
                          child: Text('admin.users.roleModerator'.tr()),
                        ),
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('admin.users.roleAdmin'.tr()),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setSheetState(() => _editRole = v);
                        setState(() => _editRole = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Spacer(),
                      OutlinedButton(
                        onPressed: _editSaving
                            ? null
                            : () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkSoft,
                          side: const BorderSide(color: AppColors.line),
                        ),
                        child: Text('common.cancel'.tr()),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _editSaving
                            ? null
                            : () async {
                                setSheetState(() => _editSaving = true);
                                setState(() => _editSaving = true);
                                final ok = await _saveEdit();
                                if (!ctx.mounted) return;
                                if (ok) {
                                  Navigator.of(ctx).pop();
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: AppColors.surface,
                        ),
                        child: Text('common.save'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _editUser = null;
        _editSaving = false;
      });
    });
  }

  Future<bool> _saveEdit() async {
    final user = _editUser;
    if (user == null) return false;
    final uid = user['id'] as String?;
    if (uid == null) return false;

    final originalRole = (user['role'] ?? 'user').toString();
    final originalName = (user['name'] ?? '').toString();
    final originalNickname = (user['nickname'] ?? '').toString();
    final newName = _editNameCtrl.text.trim();
    final newNickname = _editNicknameCtrl.text.trim();
    bool allOk = true;

    try {
      if (_editRole != originalRole) {
        final roleOk =
            await AdminRepository.changeUserRole(uid, _editRole);
        allOk = allOk && roleOk;
      }
      // User-Wunsch (2026-05): NIE den Namen überschreiben wenn er sich
      // nicht geändert hat oder leer ist. Sonst löscht die Rollen-Vergabe
      // versehentlich den User-Namen (originale Bug-Quelle).
      if (newName.isNotEmpty && newName != originalName) {
        final nameOk = await AdminRepository.updateField(
          table: 'profiles',
          id: uid,
          column: 'name',
          value: newName,
        );
        allOk = allOk && nameOk;
      }
      if (newNickname != originalNickname) {
        final nickOk = await AdminRepository.updateField(
          table: 'profiles',
          id: uid,
          column: 'nickname',
          value: newNickname.isEmpty ? null : newNickname,
        );
        allOk = allOk && nickOk;
      }
    } catch (_) {
      allOk = false;
    }

    if (!mounted) return allOk;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          allOk
              ? 'admin.users.editSaved'.tr()
              : 'admin.users.editError'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ),
    );
    if (allOk) {
      _load();
    }
    return allOk;
  }

  // ---------------- Ban / Unban ----------------

  void _openBan(Map<String, dynamic> user) {
    // Self-Guard: Admin darf sich nicht selbst bannen.
    if (user['id'] == SupabaseService.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('admin.cannotActOnSelf'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm)),
      ));
      return;
    }
    final reasonCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'admin.users.banConfirmTitle'.tr(),
            style: AppTypography.body(
              size: 16,
              color: AppColors.ink,
              weight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: reasonCtrl,
            autofocus: true,
            style: AppTypography.body(size: 14, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'admin.users.banReason'.tr(),
              hintStyle: AppTypography.caption(),
              filled: true,
              fillColor: AppColors.elevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.herzrot),
              onPressed: () async {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) return;
                Navigator.of(ctx).pop();
                final uid = user['id'] as String?;
                if (uid == null) return;
                final ok =
                    await AdminRepository.banUser(uid, reason, days: 30);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.surface,
                    content: Text(
                      ok
                          ? 'admin.users.banSuccess'.tr()
                          : 'admin.users.editError'.tr(),
                      style:
                          AppTypography.body(size: 13, color: AppColors.ink),
                    ),
                  ),
                );
                if (ok) _load();
              },
              child: Text('admin.users.banAction'.tr()),
            ),
          ],
        );
      },
    ).whenComplete(reasonCtrl.dispose);
  }

  Future<void> _unban(Map<String, dynamic> user) async {
    final uid = user['id'] as String?;
    if (uid == null) return;
    // Bestätigung — Parität zum Ban (vorher konnte man versehentlich
    // entsperren, ein Tap genügte).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('admin.users.unbanConfirmTitle'.tr(),
            style: AppTypography.body(
                size: 16, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text('admin.users.unbanConfirmBody'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.leben),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('admin.users.unbanConfirmBtn'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await AdminRepository.unbanUser(uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          ok
              ? 'admin.users.unbanSuccess'.tr()
              : 'admin.users.editError'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ),
    );
    if (ok) _load();
  }

  // ---------------- Delete ----------------

  Future<void> _openDelete(Map<String, dynamic> user) async {
    final uid = user['id'] as String?;
    if (uid == null) return;
    if (uid == SupabaseService.currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('admin.cannotActOnSelf'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm)),
      ));
      return;
    }
    final ok = await ConfirmDialog.show(
      context,
      title: 'admin.users.deleteConfirmTitle'.tr(),
      message: 'admin.users.deleteConfirmMsg'.tr(),
      confirmLabel: 'common.delete'.tr(),
      danger: true,
    );
    if (!ok) return;
    final done = await AdminRepository.deleteUser(uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          done
              ? 'admin.users.deleteSuccess'.tr()
              : 'admin.users.editError'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ),
    );
    if (done) _load();
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    final pages = (_total / _pageSize).ceil().clamp(1, 9999);
    return DashboardScaffold(
      title: 'admin.usersTitle'.tr(),
      currentRoute: '/dashboard/admin/users',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.bronze,
        foregroundColor: AppColors.voidColor,
        onPressed: _exporting ? null : _exportCsv,
        icon: _exporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.voidColor),
              )
            : const Icon(LucideIcons.fileSpreadsheet, size: 18),
        label: Text('admin.exportCsv'.tr()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ModuleSearchBar(
                      hintText: 'admin.searchUsersHint'.tr(),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RoleDropdown(
                    value: _roleFilter,
                    onChanged: _setRoleFilter,
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'admin.bulkSelect'.tr(),
                      onPressed: _toggleSelectionMode,
                      icon: Icon(
                        _selectionMode
                            ? LucideIcons.x
                            : LucideIcons.listChecks,
                        size: 20,
                        color: _selectionMode
                            ? AppColors.bronze
                            : AppColors.mute,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'admin.users.totalCount'.tr(namedArgs: {'n': '$_total'}),
                  style: AppTypography.label(size: 10, color: AppColors.mute),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const _UsersSkeleton(count: 5)
                  : _users.isEmpty
                      ? Center(
                          child: Text(
                            'admin.users.empty'.tr(),
                            style: AppTypography.caption(),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _users.length,
                          itemBuilder: (ctx, i) => _UserRow(
                            user: _users[i],
                            canEdit: _isAdmin,
                            canBan: _isAdmin,
                            canDelete: _isAdmin,
                            isModerator: _isModerator,
                            selectionMode: _selectionMode,
                            selected: _selectedIds
                                .contains(_users[i]['id']?.toString()),
                            onToggleSelect: () {
                              final id = _users[i]['id']?.toString();
                              if (id != null) _toggleSelected(id);
                            },
                            onEdit: () => _openEdit(_users[i]),
                            onBan: () => _openBan(_users[i]),
                            onUnban: () => _unban(_users[i]),
                            onDelete: () => _openDelete(_users[i]),
                          ),
                        ),
            ),
            if (_selectionMode && _selectedIds.isNotEmpty)
              _BulkBar(
                count: _selectedIds.length,
                onBan: () => _applyBulk(
                    (id) => AdminRepository.banUser(
                        id, 'admin.bulkBanReason'.tr()),
                    'ban'),
                onUnban: () => _applyBulk(
                    (id) => AdminRepository.unbanUser(id), 'unban'),
                onRole: _bulkRole,
              ),
            if (_total > _pageSize)
              _PaginationBar(
                page: _page,
                totalPages: pages,
                onPrev: _page > 0
                    ? () {
                        setState(() => _page--);
                        _load();
                      }
                    : null,
                onNext: (_page + 1) * _pageSize < _total
                    ? () {
                        setState(() => _page++);
                        _load();
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Sub-Widgets
// ============================================================================

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          dropdownColor: AppColors.elevated,
          icon: const Icon(LucideIcons.chevronDown,
              size: 14, color: AppColors.mute),
          style: AppTypography.body(size: 13, color: AppColors.ink),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('admin.users.allRoles'.tr()),
            ),
            DropdownMenuItem<String?>(
              value: 'user',
              child: Text('admin.users.roleUser'.tr()),
            ),
            DropdownMenuItem<String?>(
              value: 'moderator',
              child: Text('admin.users.roleModerator'.tr()),
            ),
            DropdownMenuItem<String?>(
              value: 'admin',
              child: Text('admin.users.roleAdmin'.tr()),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.canEdit,
    required this.canBan,
    required this.canDelete,
    required this.isModerator,
    required this.onEdit,
    required this.onBan,
    required this.onUnban,
    required this.onDelete,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelect,
  });

  final Map<String, dynamic> user;
  final bool canEdit;
  final bool canBan;
  final bool canDelete;
  final bool isModerator;
  final VoidCallback onEdit;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onDelete;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] ?? user['display_name'] ?? '—').toString();
    final nickname = (user['nickname'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final role = (user['role'] ?? 'user').toString();
    final isAdminUser = role == 'admin';
    final isBanned = user['is_banned'] == true;
    final isVerifiedEmail =
        user['verified_email'] == true || user['email_confirmed_at'] != null;
    final avatar = user['avatar_url'] as String?;
    final homeCity = (user['home_city'] ?? '').toString();
    final trustScore = user['trust_score'];
    final createdAt =
        (user['created_at'] ?? user['profile_created_at'])?.toString();
    DateTime? created;
    if (createdAt != null) {
      created = DateTime.tryParse(createdAt);
    }
    // A1: letzter Login. admin_users_view liefert last_sign_in_at.
    final lastLoginRaw = user['last_sign_in_at']?.toString();
    final lastLogin =
        lastLoginRaw != null ? DateTime.tryParse(lastLoginRaw) : null;

    final initial = (name.isNotEmpty ? name : '?').substring(0, 1).toUpperCase();

    final container = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.bronze.withValues(alpha: 0.10)
            : isBanned
                ? AppColors.herzrot.withValues(alpha: 0.08)
                : AppColors.surface,
        border: Border.all(
          color: selected
              ? AppColors.bronze
              : isBanned
                  ? AppColors.herzrot.withValues(alpha: 0.4)
                  : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? LucideIcons.checkCircle2
                      : LucideIcons.circle,
                  size: 22,
                  color: selected ? AppColors.bronze : AppColors.mute,
                ),
                const SizedBox(width: 10),
              ],
              if (avatar != null && avatar.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: avatar,
                  fadeInDuration: const Duration(milliseconds: 200),
                  imageBuilder: (_, img) => CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.elevated,
                    backgroundImage: img,
                  ),
                  placeholder: (_, __) => const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.elevated,
                  ),
                  errorWidget: (_, __, ___) => CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.elevated,
                    child: Text(
                      initial,
                      style: AppTypography.mono(
                          size: 16, color: AppColors.amber),
                    ),
                  ),
                )
              else
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.elevated,
                  child: Text(
                    initial,
                    style: AppTypography.mono(
                        size: 16, color: AppColors.amber),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.ink,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (nickname.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '@$nickname',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption(),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isAdminUser)
                const _MicroBadge(color: AppColors.amber, label: 'ADMIN'),
              if (isVerifiedEmail)
                _MicroBadge(
                  color: AppColors.tealSoft,
                  label: 'admin.verifiedBadge'.tr(),
                ),
              if (isBanned)
                _MicroBadge(
                  color: AppColors.herzrot,
                  label: 'admin.bannedBadge'.tr(),
                ),
              Text(
                _roleLabel(role),
                style: AppTypography.label(size: 9, color: AppColors.mute),
              ),
              if (homeCity.isNotEmpty)
                Text('· $homeCity', style: AppTypography.caption()),
              if (trustScore != null)
                Text(
                  '· Trust $trustScore',
                  style: AppTypography.caption(),
                ),
              if (created != null)
                Text(
                  '· ${DateFormat('dd.MM.yyyy').format(created)}',
                  style: AppTypography.caption(),
                ),
              if (lastLogin != null)
                Text(
                  '· ${'admin.lastLogin'.tr()} ${DateFormat('dd.MM.yyyy').format(lastLogin)}',
                  style: AppTypography.caption(),
                ),
            ],
          ),
          // In Selection-Mode keine Einzel-Aktionen — der Row-Tap wählt aus.
          if (!selectionMode) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _ActionPill(
                icon: LucideIcons.eye,
                label: 'admin.users.profile'.tr(),
                color: AppColors.tealSoft,
                onTap: () {
                  final uid = user['id'] as String?;
                  if (uid != null) {
                    context.push('/dashboard/profile/$uid');
                  }
                },
              ),
              if (canEdit)
                _ActionPill(
                  icon: LucideIcons.edit3,
                  label: 'common.edit'.tr(),
                  color: AppColors.amber,
                  onTap: onEdit,
                ),
              if (canBan)
                if (isBanned)
                  _ActionPill(
                    icon: LucideIcons.unlock,
                    label: 'admin.users.unban'.tr(),
                    color: AppColors.leben,
                    onTap: onUnban,
                  )
                else
                  _ActionPill(
                    icon: LucideIcons.ban,
                    label: 'admin.users.ban'.tr(),
                    color: AppColors.herzrot,
                    onTap: onBan,
                  ),
              if (canDelete)
                _ActionPill(
                  icon: LucideIcons.trash2,
                  label: 'common.delete'.tr(),
                  color: AppColors.herzrot,
                  onTap: onDelete,
                ),
            ],
          ),
          ],
        ],
      ),
    );
    // Im Selection-Mode fängt ein GestureDetector den Tap ab und toggelt
    // die Auswahl statt eine Einzel-Aktion auszulösen.
    if (selectionMode) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggleSelect,
        child: container,
      );
    }
    return container;
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'admin.users.roleAdmin'.tr().toUpperCase();
      case 'moderator':
        return 'admin.users.roleModerator'.tr().toUpperCase();
      default:
        return 'admin.users.roleUser'.tr().toUpperCase();
    }
  }
}

class _MicroBadge extends StatelessWidget {
  const _MicroBadge({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.label(size: 8, color: color),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.label(size: 10, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersSkeleton extends StatelessWidget {
  const _UsersSkeleton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: ShimmerBox(height: 80, borderRadius: 12),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onPrev,
            icon: const Icon(LucideIcons.chevronLeft, size: 14),
            label: Text('admin.users.prev'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  onPrev == null ? AppColors.mute : AppColors.inkSoft,
              side: const BorderSide(color: AppColors.line),
            ),
          ),
          const Spacer(),
          Text(
            'admin.users.pageInfo'.tr(namedArgs: {
              'page': '${page + 1}',
              'total': '$totalPages',
            }),
            style: AppTypography.caption(),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onNext,
            icon: Text('admin.users.next'.tr()),
            label: const Icon(LucideIcons.chevronRight, size: 14),
            style: FilledButton.styleFrom(
              backgroundColor:
                  onNext == null ? AppColors.elevated : AppColors.amber,
              foregroundColor:
                  onNext == null ? AppColors.mute : AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}

/// A3 Bulk-Aktions-Leiste — erscheint am unteren Rand wenn im Selection-
/// Mode mindestens ein Nutzer ausgewählt ist.
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.onBan,
    required this.onUnban,
    required this.onRole,
  });

  final int count;
  final VoidCallback onBan;
  final VoidCallback onUnban;
  final VoidCallback onRole;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              'admin.bulkSelected'.tr(namedArgs: {'n': '$count'}),
              style: AppTypography.label(size: 10, color: AppColors.bronze),
            ),
            const Spacer(),
            _BulkBtn(
                icon: LucideIcons.shieldCheck,
                label: 'admin.bulkRole'.tr(),
                color: AppColors.bronze,
                onTap: onRole),
            const SizedBox(width: 6),
            _BulkBtn(
                icon: LucideIcons.unlock,
                label: 'admin.users.unban'.tr(),
                color: AppColors.leben,
                onTap: onUnban),
            const SizedBox(width: 6),
            _BulkBtn(
                icon: LucideIcons.ban,
                label: 'admin.users.ban'.tr(),
                color: AppColors.herzrot,
                onTap: onBan),
          ],
        ),
      ),
    );
  }
}

class _BulkBtn extends StatelessWidget {
  const _BulkBtn({
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
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label,
          style: AppTypography.label(size: 9, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
      ),
    );
  }
}
