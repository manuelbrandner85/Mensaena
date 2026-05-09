import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// /dashboard/admin — Tabbed Admin-Dashboard.
/// Tabs: Übersicht · Meldungen · Beiträge · Krisen · Nutzer.
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage>
    with SingleTickerProviderStateMixin {
  bool? _isAdmin;
  bool _loading = true;
  late final _tabs = TabController(length: 5, vsync: this);

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isAdmin = false;
          _loading = false;
        });
        return;
      }
      final profile = await db
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = profile?['role'] as String? ?? 'user';
      if (!mounted) return;
      setState(() {
        _isAdmin = role == 'admin' || role == 'moderator';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isAdmin != true) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Admin')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: AppColors.ink400),
                SizedBox(height: 12),
                Text(
                  'Kein Admin-Zugriff',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  'Diese Seite ist Mensaena-Admins vorbehalten.',
                  style: TextStyle(color: AppColors.ink400),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Übersicht'),
            Tab(icon: Icon(Icons.report_outlined), text: 'Meldungen'),
            Tab(icon: Icon(Icons.article_outlined), text: 'Beiträge'),
            Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Krisen'),
            Tab(icon: Icon(Icons.people_outline), text: 'Nutzer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _OverviewTab(),
          _ReportsTab(),
          _PostsTab(),
          _CrisisTab(),
          _UsersTab(),
        ],
      ),
    );
  }
}

// ─── Übersicht ────────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(supabaseProvider);
      Map<String, dynamic>? stats;
      try {
        stats = await db.rpc<Map<String, dynamic>>('get_admin_dashboard_stats');
      } catch (_) {
        // Fallback: einzelne count-Queries
        final counts = await Future.wait<List<Map<String, dynamic>>>([
          db.from('profiles').select('id'),
          db.from('posts').select('id'),
          db.from('events').select('id'),
          db.from('crisis_reports').select('id'),
          db.from('organizations').select('id'),
          db.from('messages').select('id'),
        ]);
        stats = <String, dynamic>{
          'total_users': counts[0].length,
          'total_posts': counts[1].length,
          'total_events': counts[2].length,
          'total_crises': counts[3].length,
          'total_orgs': counts[4].length,
          'total_messages': counts[5].length,
        };
      }
      if (!mounted) return;
      setState(() {
        _stats = stats;
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
    final s = _stats ?? const <String, dynamic>{};
    final tiles = <_StatTile>[
      _StatTile(emoji: '👥', label: 'Nutzer', value: '${s['total_users'] ?? '—'}'),
      _StatTile(emoji: '📝', label: 'Beiträge', value: '${s['total_posts'] ?? '—'}'),
      _StatTile(emoji: '📅', label: 'Events', value: '${s['total_events'] ?? '—'}'),
      _StatTile(emoji: '🚨', label: 'Krisen', value: '${s['total_crises'] ?? '—'}'),
      _StatTile(emoji: '🏛️', label: 'Organisationen', value: '${s['total_orgs'] ?? '—'}'),
      _StatTile(emoji: '💬', label: 'Nachrichten', value: '${s['total_messages'] ?? '—'}'),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: tiles,
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.emoji, required this.label, required this.value});
  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary500,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reports ─────────────────────────────────────────────────────────────────

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  List<Map<String, dynamic>> _reports = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await ref
          .read(supabaseProvider)
          .from('content_reports')
          .select('*, reporter:reporter_id(name, avatar_url)')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(40);
      if (!mounted) return;
      setState(() {
        _reports = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _resolve(String id, String resolution) async {
    try {
      await ref.read(supabaseProvider).from('content_reports').update(
        <String, dynamic>{
          'status': 'resolved',
          'resolution': resolution,
          'resolved_at': DateTime.now().toIso8601String(),
        },
      ).eq('id', id);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_reports.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Keine offenen Meldungen 🎉',
            style: TextStyle(color: AppColors.ink400),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final r = _reports[i];
          final reason = r['reason'] as String? ?? '—';
          final note = r['note'] as String? ?? '';
          final reporter = r['reporter'] as Map<String, dynamic>?;
          final reporterName = reporter?['name'] as String? ?? 'Unbekannt';
          final targetType = r['target_type'] as String? ?? '';
          final targetId = r['target_id'] as String?;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (targetType.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· $targetType',
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(note, style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
                const SizedBox(height: 6),
                Text(
                  'Gemeldet von $reporterName',
                  style: const TextStyle(color: AppColors.ink400, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (targetType == 'post' && targetId != null)
                      TextButton.icon(
                        onPressed: () => context.go('${Routes.dashboardPosts}/$targetId'),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Beitrag öffnen'),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _resolve(r['id'] as String, 'dismissed'),
                      child: const Text('Verwerfen'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: () => _resolve(r['id'] as String, 'actioned'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Erledigt'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Posts ────────────────────────────────────────────────────────────────────

class _PostsTab extends ConsumerStatefulWidget {
  const _PostsTab();

  @override
  ConsumerState<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends ConsumerState<_PostsTab> {
  List<Map<String, dynamic>> _posts = const [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var q = ref
          .read(supabaseProvider)
          .from('posts')
          .select('id, title, type, status, urgency, created_at, '
              'profiles:user_id(name)');
      if (_filter != 'all') q = q.eq('status', _filter);
      final rows = await q.order('created_at', ascending: false).limit(60);
      if (!mounted) return;
      setState(() {
        _posts = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('posts')
          .update(<String, dynamic>{'status': status}).eq('id', id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _confirmDelete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Beitrag löschen?'),
        content: Text('„$title" und alle zugehörigen Daten unwiderruflich entfernen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = ref.read(supabaseProvider);
      try {
        await db.rpc<dynamic>('admin_delete_post', params: {'p_post_id': id});
      } catch (_) {
        // Manual cascade
        await db.from('posts').delete().eq('id', id);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              for (final f in const [
                ('all', 'Alle'),
                ('active', 'Aktiv'),
                ('resolved', 'Geklärt'),
                ('archived', 'Archiv'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f.$2),
                    selected: _filter == f.$1,
                    onSelected: (_) {
                      setState(() => _filter = f.$1);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _posts.isEmpty
                  ? const Center(
                      child: Text(
                        'Keine Beiträge',
                        style: TextStyle(color: AppColors.ink400),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) =>
                            _AdminPostTile(
                          data: _posts[i],
                          onSetStatus: _setStatus,
                          onDelete: _confirmDelete,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _AdminPostTile extends StatelessWidget {
  const _AdminPostTile({
    required this.data,
    required this.onSetStatus,
    required this.onDelete,
  });
  final Map<String, dynamic> data;
  final void Function(String id, String status) onSetStatus;
  final void Function(String id, String title) onDelete;

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String;
    final title = data['title'] as String? ?? '—';
    final status = data['status'] as String? ?? 'active';
    final urgency = data['urgency'] is num
        ? (data['urgency'] as num).toInt().toString()
        : '${data['urgency'] ?? '-'}';
    final created = data['created_at'] as String?;
    final time = created != null
        ? DateFormat('d. MMM', 'de').format(DateTime.parse(created))
        : '';
    final profile = data['profiles'] as Map<String, dynamic>?;
    final author = profile?['name'] as String? ?? 'Anonym';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'active'
                      ? AppColors.primary500.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: status == 'active'
                        ? AppColors.primary500
                        : AppColors.ink400,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$author · ${data['type']} · ⚠️$urgency · $time',
            style: const TextStyle(color: AppColors.ink400, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () => context.go('${Routes.dashboardPosts}/$id'),
                child: const Text('Öffnen'),
              ),
              const Spacer(),
              if (status == 'active')
                TextButton(
                  onPressed: () => onSetStatus(id, 'resolved'),
                  child: const Text('Geklärt'),
                ),
              if (status == 'active')
                TextButton(
                  onPressed: () => onSetStatus(id, 'archived'),
                  child: const Text('Archivieren'),
                ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFB91C1C),
                  size: 18,
                ),
                tooltip: 'Löschen',
                onPressed: () => onDelete(id, title),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Crisis ───────────────────────────────────────────────────────────────────

class _CrisisTab extends ConsumerStatefulWidget {
  const _CrisisTab();

  @override
  ConsumerState<_CrisisTab> createState() => _CrisisTabState();
}

class _CrisisTabState extends ConsumerState<_CrisisTab> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await ref
          .read(supabaseProvider)
          .from('crisis_reports')
          .select('id, title, urgency, status, helper_count, needed_helpers, '
              'is_verified, created_at, profiles:creator_id(name)')
          .order('created_at', ascending: false)
          .limit(60);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _verify(String id, bool value) async {
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      await db.from('crisis_reports').update(<String, dynamic>{
        'is_verified': value,
        if (value) 'verified_by': user?.id,
        if (value) 'verified_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      await _load();
    } catch (_) {}
  }

  Future<void> _markResolved(String id) async {
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      await db.from('crisis_reports').update(<String, dynamic>{
        'status': 'resolved',
        'resolved_at': DateTime.now().toIso8601String(),
        'resolved_by': user?.id,
      }).eq('id', id);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Keine Krisen-Berichte',
            style: TextStyle(color: AppColors.ink400),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final c = _items[i];
          final id = c['id'] as String;
          final title = c['title'] as String? ?? '—';
          final status = c['status'] as String? ?? 'active';
          final urgency = c['urgency'] as String? ?? '-';
          final verified = c['is_verified'] as bool? ?? false;
          final helperCount = c['helper_count'] as int? ?? 0;
          final neededHelpers = c['needed_helpers'] as int? ?? 0;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: urgency == 'critical'
                      ? const Color(0xFFB91C1C)
                      : urgency == 'high'
                          ? const Color(0xFFD97706)
                          : Colors.grey.shade300,
                  width: 4,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    if (verified)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified,
                            size: 14, color: AppColors.primary500),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'active'
                            ? const Color(0xFFFEE2E2)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: status == 'active'
                              ? const Color(0xFFB91C1C)
                              : AppColors.ink400,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$urgency · Helfer $helperCount/$neededHelpers',
                  style: const TextStyle(color: AppColors.ink400, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () =>
                          context.go('${Routes.dashboardCrisis}/$id'),
                      child: const Text('Öffnen'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _verify(id, !verified),
                      child: Text(verified ? 'Unverify' : 'Verifizieren'),
                    ),
                    if (status == 'active')
                      FilledButton(
                        onPressed: () => _markResolved(id),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Auflösen'),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Users ────────────────────────────────────────────────────────────────────

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  List<Map<String, dynamic>> _users = const [];
  bool _loading = true;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var q = ref
          .read(supabaseProvider)
          .from('profiles')
          .select(
            'id, name, email, avatar_url, role, trust_score, created_at',
          );
      if (_query.trim().isNotEmpty) {
        final t = _query.trim().replaceAll('%', '\\%');
        q = q.or('name.ilike.%$t%,email.ilike.%$t%');
      }
      final rows = await q.order('created_at', ascending: false).limit(50);
      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setRole(String id, String role) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('profiles')
          .update(<String, dynamic>{'role': role}).eq('id', id);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (v) {
              setState(() => _query = v);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted && _query == v) _load();
              });
            },
            decoration: InputDecoration(
              hintText: 'Name oder Email…',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(
                      child: Text(
                        'Keine Nutzer',
                        style: TextStyle(color: AppColors.ink400),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final u = _users[i];
                          final id = u['id'] as String;
                          final name = u['name'] as String? ?? 'Unbekannt';
                          final email = u['email'] as String? ?? '';
                          final role = u['role'] as String? ?? 'user';
                          final avatar = u['avatar_url'] as String?;
                          final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage:
                                      avatar != null ? NetworkImage(avatar) : null,
                                  backgroundColor:
                                      AppColors.primary500.withValues(alpha: 0.18),
                                  child: avatar == null
                                      ? Text(
                                          initial,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                      ),
                                      Text(
                                        email,
                                        style: const TextStyle(
                                            color: AppColors.ink400, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: role == 'admin'
                                          ? const Color(0xFFFEE2E2)
                                          : role == 'moderator'
                                              ? const Color(0xFFFFEDD5)
                                              : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      role,
                                      style: TextStyle(
                                        color: role == 'admin'
                                            ? const Color(0xFFB91C1C)
                                            : role == 'moderator'
                                                ? const Color(0xFFD97706)
                                                : AppColors.ink400,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  onSelected: (v) => _setRole(id, v),
                                  itemBuilder: (_) =>
                                      const <PopupMenuEntry<String>>[
                                    PopupMenuItem<String>(
                                      value: 'user',
                                      child: Text('User'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'moderator',
                                      child: Text('Moderator'),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'admin',
                                      child: Text('Admin'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
