import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// /dashboard/admin — gekapseltes Admin-Dashboard.
/// Greift auf die gleichen RPCs zu wie das Web-Pendant.
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  bool? _isAdmin;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _reports = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
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
      final isAdmin = role == 'admin' || role == 'moderator';
      if (!isAdmin) {
        if (!mounted) return;
        setState(() {
          _isAdmin = false;
          _loading = false;
        });
        return;
      }

      Map<String, dynamic>? stats;
      try {
        final res = await db.rpc<Map<String, dynamic>>(
          'get_admin_dashboard_stats',
        );
        stats = res;
      } catch (_) {
        stats = null;
      }

      List<Map<String, dynamic>> reports = const [];
      try {
        final rows = await db
            .from('content_reports')
            .select(
              '*, reporter:reporter_id(name, avatar_url)',
            )
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .limit(20);
        reports = List<Map<String, dynamic>>.from(rows);
      } catch (_) {
        reports = const [];
      }

      if (!mounted) return;
      setState(() {
        _isAdmin = true;
        _stats = stats;
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isAdmin = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _resolveReport(String id, String resolution) async {
    try {
      await ref.read(supabaseProvider).from('content_reports').update(
        <String, dynamic>{
          'status': 'resolved',
          'resolution': resolution,
          'resolved_at': DateTime.now().toIso8601String(),
        },
      ).eq('id', id);
      await _bootstrap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_isAdmin == false) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _bootstrap,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _bootstrap,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatsSection(stats: _stats),
            const SizedBox(height: 20),
            const _SectionLabel(
              text: 'Offene Meldungen',
              icon: Icons.report_outlined,
            ),
            const SizedBox(height: 8),
            if (_reports.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Keine offenen Meldungen 🎉',
                  style: TextStyle(color: AppColors.ink400),
                ),
              )
            else
              ..._reports.map(
                (r) => _ReportTile(
                  data: r,
                  onResolve: (id, res) => _resolveReport(id, res),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});
  final Map<String, dynamic>? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats ?? const <String, dynamic>{};
    final cards = <_StatTile>[
      _StatTile(
        label: 'Nutzer',
        value: '${s['total_users'] ?? '—'}',
        emoji: '👥',
      ),
      _StatTile(
        label: 'Beiträge',
        value: '${s['total_posts'] ?? '—'}',
        emoji: '📝',
      ),
      _StatTile(
        label: 'Events',
        value: '${s['total_events'] ?? '—'}',
        emoji: '📅',
      ),
      _StatTile(
        label: 'Krisen',
        value: '${s['total_crises'] ?? '—'}',
        emoji: '🚨',
      ),
      _StatTile(
        label: 'Organis.',
        value: '${s['total_orgs'] ?? '—'}',
        emoji: '🏛️',
      ),
      _StatTile(
        label: 'Nachrichten',
        value: '${s['total_messages'] ?? '—'}',
        emoji: '💬',
      ),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: cards,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.emoji});
  final String label;
  final String value;
  final String emoji;

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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.ink400),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: AppColors.ink400,
          ),
        ),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.data, required this.onResolve});
  final Map<String, dynamic> data;
  final void Function(String id, String resolution) onResolve;

  @override
  Widget build(BuildContext context) {
    final created = data['created_at'] as String?;
    final time = created != null
        ? DateFormat('d. MMM HH:mm', 'de').format(DateTime.parse(created))
        : '';
    final reason = data['reason'] as String? ?? 'Keine Angabe';
    final note = data['note'] as String? ?? '';
    final reporter = data['reporter'] as Map<String, dynamic>?;
    final reporterName = reporter?['name'] as String? ?? 'Unbekannt';
    final targetType = data['target_type'] as String? ?? '';
    final targetId = data['target_id'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              const SizedBox(width: 6),
              if (targetType.isNotEmpty)
                Text(
                  '· $targetType',
                  style: const TextStyle(
                    color: AppColors.ink400,
                    fontSize: 11,
                  ),
                ),
              const Spacer(),
              Text(
                time,
                style: const TextStyle(color: AppColors.ink400, fontSize: 11),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
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
                  onPressed: () =>
                      context.go('${Routes.dashboardPosts}/$targetId'),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Beitrag öffnen'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => onResolve(data['id'] as String, 'dismissed'),
                child: const Text('Verwerfen'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: () => onResolve(data['id'] as String, 'actioned'),
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
  }
}
