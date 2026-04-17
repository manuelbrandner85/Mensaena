import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';

final _adminStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final users = await client.from('profiles').select('id');
  final posts = await client.from('posts').select('id').eq('status', 'active');
  final crises = await client.from('crises').select('id').inFilter('status', ['active', 'in_progress']);
  final reports = await client.from('content_reports').select('id').eq('status', 'pending');
  final interactions = await client.from('interactions').select('id').eq('status', 'requested');
  return {
    'users': (users as List).length,
    'posts': (posts as List).length,
    'crises': (crises as List).length,
    'reports': (reports as List).length,
    'interactions': (interactions as List).length,
  };
});

final _adminUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('profiles').select('id, name, nickname, email, role, avatar_url, is_banned, created_at').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _adminPostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('posts').select('id, title, type, status, user_id, created_at').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _adminReportsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('content_reports').select('*').eq('status', 'pending').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _adminCrisesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('crises').select('id, title, category, urgency, status, creator_id, created_at').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _adminEventsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('events').select('id, title, category, status, start_date, user_id, created_at').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _adminBoardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('board_posts').select('id, title, category, status, is_pinned, user_id, created_at').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _adminOrgsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('organizations').select('id, name, category, city, is_verified, is_active, created_at').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _adminFarmsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('farm_listings').select('id, name, city, country, is_public, is_verified, created_at').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _adminTimebankProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('timebank_entries').select('id, giver_id, receiver_id, hours, description, status, created_at').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

final _adminGroupsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('groups').select('id, name, category, status, member_count, is_public, created_at').order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(data);
});

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (p) {
          if (p == null || (p.role != 'admin' && p.role != 'moderator')) {
            return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline, size: 56, color: AppColors.textMuted),
                SizedBox(height: 12),
                Text('Kein Zugriff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text('Admin-Rechte erforderlich', style: TextStyle(color: AppColors.textMuted)),
              ]),
            );
          }
          return DefaultTabController(
            length: 11,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('§ 99 · Admin'),
                bottom: const TabBar(
                  isScrollable: true,
                  labelColor: AppColors.primary500,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary500,
                  tabs: [
                    Tab(text: 'Übersicht'),
                    Tab(text: 'Benutzer'),
                    Tab(text: 'Beiträge'),
                    Tab(text: 'Meldungen'),
                    Tab(text: 'Krisen'),
                    Tab(text: 'Events'),
                    Tab(text: 'Aushänge'),
                    Tab(text: 'Organisationen'),
                    Tab(text: 'Höfe'),
                    Tab(text: 'Zeitbank'),
                    Tab(text: 'Gruppen'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _OverviewTab(),
                  _UsersTab(),
                  _PostsTab(),
                  _ReportsTab(),
                  _CrisesTab(),
                  _EventsTab(),
                  _BoardTab(),
                  _OrgsTab(),
                  _FarmsTab(),
                  _TimebankTab(),
                  _GroupsTab(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);
    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (stats) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminStatsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(label: 'Benutzer', value: stats['users'] ?? 0, icon: Icons.people, color: AppColors.primary500),
                _StatCard(label: 'Aktive Beiträge', value: stats['posts'] ?? 0, icon: Icons.article, color: AppColors.info),
                _StatCard(label: 'Aktive Krisen', value: stats['crises'] ?? 0, icon: Icons.warning, color: AppColors.emergency),
                _StatCard(label: 'Offene Meldungen', value: stats['reports'] ?? 0, icon: Icons.flag, color: AppColors.warning),
              ],
            ),
            const SizedBox(height: 16),
            _StatCard(label: 'Offene Anfragen', value: stats['interactions'] ?? 0, icon: Icons.handshake, color: const Color(0xFF8B5CF6)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_adminUsersProvider);
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (users) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminUsersProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final u = users[i];
            final name = u['nickname'] as String? ?? u['name'] as String? ?? 'Unbekannt';
            final role = u['role'] as String? ?? 'user';
            final isBanned = u['is_banned'] as bool? ?? false;
            final createdAt = DateTime.tryParse(u['created_at'] as String? ?? '');
            return ListTile(
              leading: AvatarWidget(imageUrl: u['avatar_url'] as String?, name: name, size: 40),
              title: Row(children: [
                Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: role == 'admin' ? AppColors.emergency.withValues(alpha: 0.1) : role == 'moderator' ? AppColors.warning.withValues(alpha: 0.1) : AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: role == 'admin' ? AppColors.emergency : role == 'moderator' ? AppColors.warning : AppColors.textMuted)),
                ),
                if (isBanned) ...[const SizedBox(width: 4), const Icon(Icons.block, size: 14, color: AppColors.error)],
              ]),
              subtitle: Text(u['email'] as String? ?? '', style: const TextStyle(fontSize: 12)),
              trailing: createdAt != null ? Text(timeago.format(createdAt, locale: 'de'), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)) : null,
              onTap: () => _showUserActions(context, ref, u),
            );
          },
        ),
      ),
    );
  }

  void _showUserActions(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final name = user['nickname'] as String? ?? user['name'] as String? ?? 'Unbekannt';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('Rolle ändern'),
            onTap: () async {
              Navigator.pop(ctx);
              final newRole = await showDialog<String>(context: context, builder: (c) => SimpleDialog(
                title: const Text('Rolle wählen'),
                children: ['user', 'moderator', 'admin'].map((r) => SimpleDialogOption(onPressed: () => Navigator.pop(c, r), child: Text(r))).toList(),
              ));
              if (newRole != null) {
                await ref.read(supabaseProvider).from('profiles').update({'role': newRole}).eq('id', userId);
                ref.invalidate(_adminUsersProvider);
              }
            },
          ),
          ListTile(
            leading: Icon(user['is_banned'] == true ? Icons.check_circle : Icons.block, color: AppColors.error),
            title: Text(user['is_banned'] == true ? 'Entsperren' : 'Sperren'),
            onTap: () async {
              Navigator.pop(ctx);
              await ref.read(supabaseProvider).from('profiles').update({'is_banned': !(user['is_banned'] as bool? ?? false)}).eq('id', userId);
              ref.invalidate(_adminUsersProvider);
            },
          ),
        ]),
      ),
    );
  }
}

class _PostsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(_adminPostsProvider);
    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (posts) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminPostsProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = posts[i];
            final status = p['status'] as String? ?? 'active';
            return ListTile(
              title: Text(p['title'] as String? ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${p['type']} · $status', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  final client = ref.read(supabaseProvider);
                  if (v == 'delete') {
                    await client.from('posts').delete().eq('id', p['id']);
                  } else {
                    await client.from('posts').update({'status': v}).eq('id', p['id']);
                  }
                  ref.invalidate(_adminPostsProvider);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'active', child: Text('Aktivieren')),
                  PopupMenuItem(value: 'archived', child: Text('Archivieren')),
                  PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: AppColors.error))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(_adminReportsProvider);
    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (reports) {
        if (reports.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, size: 56, color: AppColors.success),
            SizedBox(height: 12),
            Text('Keine offenen Meldungen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_adminReportsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = reports[i];
              final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '');
              return ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.flag, color: AppColors.warning, size: 20),
                ),
                title: Text(r['reason'] as String? ?? 'Meldung', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('${r['content_type']} · ${r['details'] ?? 'Keine Details'}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: AppColors.success, size: 20),
                    tooltip: 'Erledigt',
                    onPressed: () async {
                      final userId = ref.read(currentUserIdProvider);
                      await ref.read(supabaseProvider).from('content_reports').update({'status': 'resolved', 'resolved_by': userId, 'resolved_at': DateTime.now().toIso8601String()}).eq('id', r['id']);
                      ref.invalidate(_adminReportsProvider);
                      ref.invalidate(_adminStatsProvider);
                    },
                  ),
                  if (createdAt != null) Text(timeago.format(createdAt, locale: 'de'), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ]),
              );
            },
          ),
        );
      },
    );
  }
}

class _EventsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(_adminEventsProvider);
    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (events) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminEventsProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: events.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = events[i];
            final status = e['status'] as String? ?? 'active';
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.event, color: AppColors.info, size: 20),
              ),
              title: Text(e['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${e['category'] ?? '-'} · $status', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  final client = ref.read(supabaseProvider);
                  if (v == 'delete') {
                    await client.from('events').delete().eq('id', e['id']);
                  } else {
                    await client.from('events').update({'status': v}).eq('id', e['id']);
                  }
                  ref.invalidate(_adminEventsProvider);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'active', child: Text('Aktivieren')),
                  PopupMenuItem(value: 'cancelled', child: Text('Absagen')),
                  PopupMenuItem(value: 'completed', child: Text('Abgeschlossen')),
                  PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: AppColors.error))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BoardTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(_adminBoardProvider);
    return boardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (posts) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminBoardProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = posts[i];
            final pinned = p['is_pinned'] as bool? ?? false;
            final status = p['status'] as String? ?? 'active';
            return ListTile(
              leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, color: pinned ? AppColors.warning : AppColors.textMuted, size: 20),
              title: Text(p['title'] as String? ?? '(ohne Titel)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${p['category'] ?? '-'} · $status', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  final client = ref.read(supabaseProvider);
                  if (v == 'delete') {
                    await client.from('board_posts').delete().eq('id', p['id']);
                  } else if (v == 'pin') {
                    await client.from('board_posts').update({'is_pinned': !pinned}).eq('id', p['id']);
                  } else {
                    await client.from('board_posts').update({'status': v}).eq('id', p['id']);
                  }
                  ref.invalidate(_adminBoardProvider);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'pin', child: Text(pinned ? 'Entpinnen' : 'Anpinnen')),
                  const PopupMenuItem(value: 'active', child: Text('Aktivieren')),
                  const PopupMenuItem(value: 'archived', child: Text('Archivieren')),
                  const PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: AppColors.error))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrgsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(_adminOrgsProvider);
    return orgsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (orgs) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminOrgsProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: orgs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final o = orgs[i];
            final verified = o['is_verified'] as bool? ?? false;
            final active = o['is_active'] as bool? ?? true;
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primary500.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(verified ? Icons.verified : Icons.business, color: AppColors.primary500, size: 20),
              ),
              title: Row(children: [
                Flexible(child: Text(o['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: AppColors.primary500)),
              ]),
              subtitle: Text('${o['category'] ?? '-'} · ${o['city'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  final client = ref.read(supabaseProvider);
                  if (v == 'delete') {
                    await client.from('organizations').delete().eq('id', o['id']);
                  } else if (v == 'verify') {
                    await client.from('organizations').update({'is_verified': !verified}).eq('id', o['id']);
                  } else if (v == 'toggle_active') {
                    await client.from('organizations').update({'is_active': !active}).eq('id', o['id']);
                  }
                  ref.invalidate(_adminOrgsProvider);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'verify', child: Text(verified ? 'Verifizierung aufheben' : 'Verifizieren')),
                  PopupMenuItem(value: 'toggle_active', child: Text(active ? 'Deaktivieren' : 'Aktivieren')),
                  const PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: AppColors.error))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FarmsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmsAsync = ref.watch(_adminFarmsProvider);
    return farmsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (farms) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminFarmsProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: farms.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final f = farms[i];
            final verified = f['is_verified'] as bool? ?? false;
            final isPublic = f['is_public'] as bool? ?? true;
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.agriculture, color: AppColors.success, size: 20),
              ),
              title: Row(children: [
                Flexible(child: Text(f['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: AppColors.success)),
              ]),
              subtitle: Text('${f['city'] ?? ''} · ${f['country'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  final client = ref.read(supabaseProvider);
                  if (v == 'delete') {
                    await client.from('farm_listings').delete().eq('id', f['id']);
                  } else if (v == 'verify') {
                    await client.from('farm_listings').update({'is_verified': !verified}).eq('id', f['id']);
                  } else if (v == 'toggle_public') {
                    await client.from('farm_listings').update({'is_public': !isPublic}).eq('id', f['id']);
                  }
                  ref.invalidate(_adminFarmsProvider);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'verify', child: Text(verified ? 'Verifizierung aufheben' : 'Verifizieren')),
                  PopupMenuItem(value: 'toggle_public', child: Text(isPublic ? 'Ausblenden' : 'Veröffentlichen')),
                  const PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: AppColors.error))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TimebankTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(_adminTimebankProvider);
    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (entries) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminTimebankProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = entries[i];
            final status = e['status'] as String? ?? 'pending';
            final hours = (e['hours'] as num?)?.toStringAsFixed(1) ?? '0';
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primary500.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.access_time, color: AppColors.primary500, size: 20),
              ),
              title: Text('$hours Stunden', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('${e['description'] ?? '-'} · $status', style: const TextStyle(fontSize: 12, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  final client = ref.read(supabaseProvider);
                  if (v == 'delete') {
                    await client.from('timebank_entries').delete().eq('id', e['id']);
                  } else {
                    await client.from('timebank_entries').update({'status': v}).eq('id', e['id']);
                  }
                  ref.invalidate(_adminTimebankProvider);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'confirmed', child: Text('Bestätigen')),
                  PopupMenuItem(value: 'rejected', child: Text('Ablehnen')),
                  PopupMenuItem(value: 'pending', child: Text('Ausstehend')),
                  PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: AppColors.error))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GroupsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(_adminGroupsProvider);
    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (groups) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminGroupsProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final g = groups[i];
            final status = g['status'] as String? ?? 'active';
            final memberCount = g['member_count'] as int? ?? 0;
            final isPublic = g['is_public'] as bool? ?? true;
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.group, color: AppColors.info, size: 20),
              ),
              title: Row(children: [
                Flexible(child: Text(g['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (!isPublic) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.lock, size: 12, color: AppColors.textMuted)),
              ]),
              subtitle: Text('${g['category'] ?? '-'} · $memberCount Mitglieder · $status', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  final client = ref.read(supabaseProvider);
                  if (v == 'delete') {
                    await client.from('groups').delete().eq('id', g['id']);
                  } else {
                    await client.from('groups').update({'status': v}).eq('id', g['id']);
                  }
                  ref.invalidate(_adminGroupsProvider);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'active', child: Text('Aktivieren')),
                  PopupMenuItem(value: 'archived', child: Text('Archivieren')),
                  PopupMenuItem(value: 'delete', child: Text('Löschen', style: TextStyle(color: AppColors.error))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CrisesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crisesAsync = ref.watch(_adminCrisesProvider);
    return crisesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (crises) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_adminCrisesProvider),
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: crises.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = crises[i];
            final status = c['status'] as String? ?? 'active';
            final urgency = c['urgency'] as String? ?? 'medium';
            return ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: urgency == 'critical' ? AppColors.emergency.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning, size: 20, color: urgency == 'critical' ? AppColors.emergency : AppColors.warning),
              ),
              title: Text(c['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('$urgency · $status', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  await ref.read(supabaseProvider).from('crises').update({'status': v}).eq('id', c['id']);
                  ref.invalidate(_adminCrisesProvider);
                  ref.invalidate(_adminStatsProvider);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'active', child: Text('Aktiv setzen')),
                  PopupMenuItem(value: 'in_progress', child: Text('In Bearbeitung')),
                  PopupMenuItem(value: 'resolved', child: Text('Gelöst')),
                  PopupMenuItem(value: 'false_alarm', child: Text('Fehlalarm', style: TextStyle(color: AppColors.warning))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
