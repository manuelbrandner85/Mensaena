import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// Generic admin tab — lädt eine Tabelle, zeigt Liste mit Admin-Aktionen.
class _AdminListTab extends ConsumerStatefulWidget {
  const _AdminListTab({
    required this.table,
    required this.select,
    this.orderBy = 'created_at',
    this.orderAsc = false,
    this.statusFilter,
    required this.tileBuilder,
    required this.emptyText,
  });

  final String table;
  final String select;
  final String orderBy;
  final bool orderAsc;
  final String? statusFilter;
  final Widget Function(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
    Future<void> Function() reload,
  ) tileBuilder;
  final String emptyText;

  @override
  ConsumerState<_AdminListTab> createState() => _AdminListTabState();
}

class _AdminListTabState extends ConsumerState<_AdminListTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var q =
          ref.read(supabaseProvider).from(widget.table).select(widget.select);
      if (widget.statusFilter != null) {
        q = q.eq('status', widget.statusFilter!);
      }
      final rows =
          await q.order(widget.orderBy, ascending: widget.orderAsc).limit(80);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            widget.emptyText,
            style: const TextStyle(color: AppColors.ink400),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) => widget.tileBuilder(context, ref, _rows[i], _load),
      ),
    );
  }
}

class _AdminListTile extends StatelessWidget {
  const _AdminListTile({
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.onOpen,
    this.actions,
    this.urgencyColor,
  });

  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onOpen;
  final List<Widget>? actions;
  final Color? urgencyColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: urgencyColor != null
            ? Border(left: BorderSide(color: urgencyColor!, width: 4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppColors.ink400)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: badgeColor ?? AppColors.ink400,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(color: AppColors.ink400, fontSize: 11),
            ),
          ],
          if (actions != null || onOpen != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onOpen != null)
                  TextButton(onPressed: onOpen, child: const Text('Öffnen')),
                const Spacer(),
                if (actions != null) ...actions!,
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Events Tab ──────────────────────────────────────────────────────────────

class AdminEventsTab extends StatelessWidget {
  const AdminEventsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminListTab(
      table: 'events',
      select:
          'id, title, category, status, start_date, attendee_count, max_attendees',
      orderBy: 'start_date',
      orderAsc: true,
      tileBuilder: (ctx, ref, row, reload) {
        final id = row['id'] as String;
        final title = row['title'] as String? ?? '—';
        final cat = row['category'] as String? ?? '';
        final status = row['status'] as String? ?? 'active';
        final start = row['start_date'] as String?;
        final time = start != null
            ? DateFormat('d. MMM HH:mm', 'de').format(DateTime.parse(start))
            : '';
        return _AdminListTile(
          title: title,
          subtitle: '$cat · $time · ${row['attendee_count'] ?? 0} dabei',
          badge: status,
          badgeColor: status == 'active'
              ? AppColors.primary500
              : AppColors.ink400,
          onOpen: () => ctx.go('${Routes.dashboardEvents}/$id'),
          actions: [
            TextButton(
              onPressed: () async {
                await ref
                    .read(supabaseProvider)
                    .from('events')
                    .update(<String, dynamic>{'status': 'archived'})
                    .eq('id', id);
                await reload();
              },
              child: const Text('Archivieren'),
            ),
          ],
        );
      },
      emptyText: 'Keine Events.',
    );
  }
}

// ─── Board Tab ───────────────────────────────────────────────────────────────

class AdminBoardTab extends StatelessWidget {
  const AdminBoardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminListTab(
      table: 'board_posts',
      select: 'id, title, status, urgency, helpful_count, created_at',
      tileBuilder: (ctx, ref, row, reload) {
        final id = row['id'] as String;
        final title = row['title'] as String? ?? '—';
        final status = row['status'] as String? ?? 'active';
        final urgency = row['urgency'] as String? ?? 'normal';
        final helpful = row['helpful_count'] ?? 0;
        return _AdminListTile(
          title: title,
          subtitle: 'Urgency: $urgency · 👍 $helpful',
          badge: status,
          badgeColor: status == 'active'
              ? AppColors.primary500
              : AppColors.ink400,
          urgencyColor: urgency == 'high'
              ? AppColors.emergency500
              : urgency == 'urgent'
                  ? const Color(0xFFD97706)
                  : null,
          actions: [
            TextButton(
              onPressed: () async {
                await ref
                    .read(supabaseProvider)
                    .from('board_posts')
                    .update(<String, dynamic>{'status': 'archived'})
                    .eq('id', id);
                await reload();
              },
              child: const Text('Archivieren'),
            ),
          ],
        );
      },
      emptyText: 'Kein Pinnwand-Eintrag.',
    );
  }
}

// ─── Groups Tab ──────────────────────────────────────────────────────────────

class AdminGroupsTab extends StatelessWidget {
  const AdminGroupsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminListTab(
      table: 'groups',
      select:
          'id, name, category, member_count, post_count, is_private, created_at',
      tileBuilder: (ctx, ref, row, reload) {
        final id = row['id'] as String;
        final name = row['name'] as String? ?? '—';
        final cat = row['category'] as String? ?? '';
        final members = row['member_count'] ?? 0;
        final posts = row['post_count'] ?? 0;
        final isPrivate = (row['is_private'] as bool?) ?? false;
        return _AdminListTile(
          title: name,
          subtitle: '$cat · 👥 $members · 📝 $posts',
          badge: isPrivate ? 'privat' : 'öffentlich',
          badgeColor:
              isPrivate ? const Color(0xFFD97706) : AppColors.primary500,
          onOpen: () => ctx.go('${Routes.dashboardGroups}/$id'),
        );
      },
      emptyText: 'Keine Gruppen.',
    );
  }
}

// ─── Organizations Tab ──────────────────────────────────────────────────────

class AdminOrganizationsTab extends StatelessWidget {
  const AdminOrganizationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminListTab(
      table: 'organizations',
      select: 'id, name, category, is_verified, member_count, created_at',
      tileBuilder: (ctx, ref, row, reload) {
        final id = row['id'] as String;
        final name = row['name'] as String? ?? '—';
        final cat = row['category'] as String? ?? '';
        final verified = (row['is_verified'] as bool?) ?? false;
        final members = row['member_count'] ?? 0;
        return _AdminListTile(
          title: name,
          subtitle: '$cat · 👥 $members',
          badge: verified ? 'verifiziert' : 'unverifiziert',
          badgeColor:
              verified ? AppColors.primary500 : const Color(0xFFD97706),
          onOpen: () => ctx.go('${Routes.dashboardOrganizations}/$id'),
          actions: [
            TextButton(
              onPressed: () async {
                await ref.read(supabaseProvider).from('organizations').update(
                  <String, dynamic>{'is_verified': !verified},
                ).eq('id', id);
                await reload();
              },
              child: Text(verified ? 'Unverify' : 'Verifizieren'),
            ),
          ],
        );
      },
      emptyText: 'Keine Organisationen.',
    );
  }
}

// ─── Challenges Tab ──────────────────────────────────────────────────────────

class AdminChallengesTab extends StatelessWidget {
  const AdminChallengesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminListTab(
      table: 'challenges',
      select: 'id, title, category, status, participant_count, end_date',
      tileBuilder: (ctx, ref, row, reload) {
        final id = row['id'] as String;
        final title = row['title'] as String? ?? '—';
        final cat = row['category'] as String? ?? '';
        final status = row['status'] as String? ?? 'active';
        final p = row['participant_count'] ?? 0;
        final end = row['end_date'] as String?;
        final endStr = end != null
            ? DateFormat('d. MMM', 'de').format(DateTime.parse(end))
            : '—';
        return _AdminListTile(
          title: title,
          subtitle: '$cat · 👥 $p · bis $endStr',
          badge: status,
          badgeColor: status == 'active'
              ? AppColors.primary500
              : AppColors.ink400,
          actions: [
            TextButton(
              onPressed: () async {
                await ref.read(supabaseProvider).from('challenges').update(
                  <String, dynamic>{'status': 'completed'},
                ).eq('id', id);
                await reload();
              },
              child: const Text('Abschließen'),
            ),
          ],
        );
      },
      emptyText: 'Keine Challenges.',
    );
  }
}

// ─── Contact Messages Tab ───────────────────────────────────────────────────

class AdminContactMessagesTab extends StatelessWidget {
  const AdminContactMessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return _AdminListTab(
      table: 'contact_messages',
      select: 'id, name, email, subject, message, status, created_at',
      tileBuilder: (ctx, ref, row, reload) {
        final id = row['id'] as String;
        final name = row['name'] as String? ?? '—';
        final email = row['email'] as String? ?? '—';
        final subject = row['subject'] as String? ?? 'Nachricht';
        final msg = row['message'] as String? ?? '';
        final status = row['status'] as String? ?? 'new';
        return _AdminListTile(
          title: '$subject – $name',
          subtitle:
              '$email\n${msg.length > 80 ? '${msg.substring(0, 80)}…' : msg}',
          badge: status,
          badgeColor: status == 'new'
              ? AppColors.emergency500
              : AppColors.ink400,
          actions: [
            TextButton(
              onPressed: () async {
                await ref.read(supabaseProvider).from('contact_messages').update(
                  <String, dynamic>{'status': 'replied'},
                ).eq('id', id);
                await reload();
              },
              child: const Text('Erledigt'),
            ),
          ],
        );
      },
      emptyText: 'Keine offenen Nachrichten.',
    );
  }
}
