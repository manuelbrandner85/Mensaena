import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/module_search_bar.dart';

/// SKILL: mensaena-features (Admin Phase 5)
/// 1:1 zu `src/app/dashboard/admin/components/UsersTab.tsx`.
/// User-Liste mit Ban/Unban + Verify-Toggle + Make-Admin-Toggle.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _search = '';
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = AdminRepository.recent('profiles', orderBy: 'created_at');
    });
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((u) {
      final name = (u['display_name'] ?? u['name'] ?? '').toString();
      final email = (u['email'] ?? '').toString();
      return name.toLowerCase().contains(q) ||
          email.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _toggleField(
    Map<String, dynamic> user,
    String column,
    String label,
  ) async {
    final current = user[column] == true;
    final ok = await AdminRepository.updateField(
      table: 'profiles',
      id: user['id'] as String,
      column: column,
      value: !current,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok ? '$label ${current ? "entfernt" : "gesetzt"}' : 'Fehler.',
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Admin: Users',
      currentRoute: '/dashboard/admin/users',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: ModuleSearchBar(
                hintText: 'Name oder E-Mail suchen…',
                onChanged: (v) => setState(() => _search = v),
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
                      return const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.amber),
                      );
                    }
                    final rows = _apply(snap.data ?? const []);
                    if (rows.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: const [
                          SizedBox(height: 60),
                          EmptyStateCard(
                            icon: LucideIcons.users,
                            title: 'Keine Benutzer.',
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => _UserRow(
                        row: rows[i],
                        onToggleField: _toggleField,
                      ),
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

class _UserRow extends StatelessWidget {
  const _UserRow({required this.row, required this.onToggleField});

  final Map<String, dynamic> row;
  final Future<void> Function(
      Map<String, dynamic> user, String column, String label) onToggleField;

  @override
  Widget build(BuildContext context) {
    final name = (row['display_name'] ?? row['name'] ?? '—').toString();
    final email = (row['email'] ?? '').toString();
    final city = (row['home_city'] ?? '').toString();
    final isBanned = row['is_banned'] == true;
    final isVerified = row['is_verified'] == true;
    final isAdmin = row['is_admin'] == true;
    final avatar = row['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBanned
            ? AppColors.herzrot.withValues(alpha: 0.08)
            : AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(
          color: isBanned
              ? AppColors.herzrot.withValues(alpha: 0.5)
              : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.elevated,
                backgroundImage:
                    avatar != null ? NetworkImage(avatar) : null,
                child: avatar == null
                    ? Text(
                        (name.isNotEmpty ? name : '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: AppTypography.mono(
                            size: 14, color: AppColors.amber),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
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
                        if (isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('ADMIN',
                                style: AppTypography.label(
                                    size: 7, color: AppColors.amber)),
                          ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.badgeCheck,
                              size: 12, color: AppColors.tealSoft),
                        ],
                        if (isBanned) ...[
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.ban,
                              size: 12, color: AppColors.herzrot),
                        ],
                      ],
                    ),
                    if (email.isNotEmpty)
                      Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption()),
                    if (city.isNotEmpty)
                      Text(city, style: AppTypography.caption()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Btn(
                icon: isBanned ? LucideIcons.unlock : LucideIcons.ban,
                label: isBanned ? 'Entsperren' : 'Sperren',
                color: AppColors.herzrot,
                onTap: () => onToggleField(row, 'is_banned', 'Sperre'),
              ),
              _Btn(
                icon: LucideIcons.badgeCheck,
                label: isVerified ? 'Unverifizieren' : 'Verifizieren',
                color: AppColors.tealSoft,
                onTap: () =>
                    onToggleField(row, 'is_verified', 'Verifizierung'),
              ),
              _Btn(
                icon: LucideIcons.shield,
                label: isAdmin ? 'Admin entfernen' : 'Admin',
                color: AppColors.amber,
                onTap: () => onToggleField(row, 'is_admin', 'Admin'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
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
            Text(label, style: AppTypography.label(size: 9, color: color)),
          ],
        ),
      ),
    );
  }
}
