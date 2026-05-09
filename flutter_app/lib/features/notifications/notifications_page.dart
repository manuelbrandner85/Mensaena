import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
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
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final rows = await db
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await ref
          .read(supabaseProvider)
          .from('notifications')
          .update(<String, dynamic>{'read_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      await _load();
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      final user = ref.read(supabaseProvider).auth.currentUser;
      if (user == null) return;
      await ref
          .read(supabaseProvider)
          .from('notifications')
          .update(<String, dynamic>{'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', user.id)
          .filter('read_at', 'is', null);
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => n['read_at'] == null).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Benachrichtigungen'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Alle gelesen'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 48, color: AppColors.ink400),
                        SizedBox(height: 12),
                        Text(
                          'Keine Benachrichtigungen',
                          style: TextStyle(color: AppColors.ink400),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _NotificationTile(data: _items[i], onMarkRead: _markRead),
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.data, required this.onMarkRead});
  final Map<String, dynamic> data;
  final ValueChanged<String> onMarkRead;

  @override
  Widget build(BuildContext context) {
    final isUnread = data['read_at'] == null;
    final created = data['created_at'] as String?;
    final time = created != null
        ? DateFormat('d. MMM HH:mm', 'de').format(DateTime.parse(created))
        : '';
    final title = data['title'] as String? ?? 'Benachrichtigung';
    final body = data['body'] as String? ?? '';
    return Material(
      color: isUnread ? AppColors.primary500.withValues(alpha: 0.05) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isUnread ? () => onMarkRead(data['id'] as String) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isUnread ? AppColors.primary500 : Colors.transparent,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: const TextStyle(
                          color: AppColors.ink700,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.ink400,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
