import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/realtime_feed.dart';

/// /dashboard/notifications — Pendant zum Web-Notification-Center.
/// Filter-Chips nach category, Mark-as-read, Tap-to-link, Pull-to-refresh.
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
    with RealtimeFeedMixin {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String _filter = 'all';

  @override
  String get realtimeChannelName => 'notifications-feed-realtime';

  @override
  List<FeedRealtimeRule> get realtimeRules => const [
        FeedRealtimeRule(
          event: PostgresChangeEvent.insert,
          table: 'notifications',
          action: FeedRealtimeAction.bumpNewCount,
        ),
      ];

  @override
  bool shouldBumpForInsert(Map<String, dynamic> row) {
    // Notifications gehören uns; nur wenn user_id == ich ist es relevant.
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;
    if (myId == null) return false;
    if (row['user_id'] != myId) return false;
    if (_filter != 'all' && row['category'] != _filter) return false;
    return true;
  }

  @override
  Future<void> reloadFeed() => _load();

  static const _filters = [
    (value: 'all', label: 'Alle', icon: Icons.notifications_outlined),
    (value: 'message', label: 'Nachrichten', icon: Icons.chat_bubble_outline),
    (value: 'interaction', label: 'Interaktionen', icon: Icons.handshake_outlined),
    (value: 'trust_rating', label: 'Bewertungen', icon: Icons.star_outline),
    (value: 'post_nearby', label: 'Posts', icon: Icons.location_on_outlined),
    (value: 'mention', label: 'Erwähnungen', icon: Icons.alternate_email),
    (value: 'system', label: 'System', icon: Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    subscribeRealtime();
  }

  void _showNewItems() {
    resetNewItemCount();
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
      var query = db
          .from('notifications')
          .select('*, actor:actor_id(name, avatar_url)')
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null);
      if (_filter != 'all') {
        query = query.eq('category', _filter);
      }
      final rows = await query.order('created_at', ascending: false).limit(80);
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
      final now = DateTime.now().toIso8601String();
      await ref.read(supabaseProvider).from('notifications').update(
        <String, dynamic>{
          'read': true,
          'read_at': now,
        },
      ).eq('id', id);
      // optimistic update
      setState(() {
        _items = _items
            .map(
              (n) => n['id'] == id
                  ? {...n, 'read': true, 'read_at': now}
                  : n,
            )
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    HapticFeedback.lightImpact();
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      try {
        await db.rpc<dynamic>(
          'mark_all_notifications_read',
          params: <String, dynamic>{
            'p_user_id': user.id,
            if (_filter != 'all') 'p_category': _filter,
          },
        );
      } catch (_) {
        // Fallback ohne RPC: direkter Update
        var q = db.from('notifications').update(<String, dynamic>{
          'read': true,
          'read_at': DateTime.now().toIso8601String(),
        }).eq('user_id', user.id).eq('read', false);
        if (_filter != 'all') q = q.eq('category', _filter);
        await q;
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _openPreferencesSheet() async {
    final db = ref.read(supabaseProvider);
    final user = db.auth.currentUser;
    if (user == null) return;

    Map<String, dynamic>? profile;
    try {
      profile = await db
          .from('profiles')
          .select(
            'notify_new_messages, notify_new_interactions, notify_nearby_posts, '
            'notify_trust_ratings, notify_system, notify_email, notify_push, '
            'notify_sound',
          )
          .eq('id', user.id)
          .maybeSingle();
    } catch (_) {}

    if (!mounted) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PreferencesSheet(initial: profile ?? const {}),
    );
    if (updated == null) return;
    HapticFeedback.lightImpact();
    try {
      await db.from('profiles').update(updated).eq('id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen gespeichert')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _delete(String id) async {
    HapticFeedback.lightImpact();
    try {
      await ref.read(supabaseProvider).from('notifications').update(
        <String, dynamic>{'deleted_at': DateTime.now().toIso8601String()},
      ).eq('id', id);
      setState(() {
        _items = _items.where((n) => n['id'] != id).toList();
      });
    } catch (_) {}
  }

  void _open(Map<String, dynamic> n) {
    final id = n['id'] as String?;
    if (id != null && (n['read'] != true || n['read_at'] == null)) {
      unawaited(_markRead(id));
    }
    final link = n['link'] as String?;
    if (link == null || link.isEmpty) return;
    // Web: link ist immer relativer Pfad ab `/dashboard/...` oder absolute URL
    if (link.startsWith('http')) {
      // External URL ignorieren – wir wollen die App nicht verlassen
      return;
    }
    context.go(link);
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate() {
    final groups = <String, List<Map<String, dynamic>>>{};
    final today = DateTime.now();
    for (final n in _items) {
      final created = n['created_at'] as String?;
      if (created == null) continue;
      final dt = DateTime.parse(created);
      final daysAgo = today.difference(dt).inDays;
      String key;
      if (daysAgo == 0) {
        key = 'Heute';
      } else if (daysAgo == 1) {
        key = 'Gestern';
      } else if (daysAgo < 7) {
        key = 'Diese Woche';
      } else if (daysAgo < 30) {
        key = 'Diesen Monat';
      } else {
        key = 'Älter';
      }
      groups.putIfAbsent(key, () => []).add(n);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => n['read'] != true).length;
    final groups = _groupByDate();
    final groupOrder = ['Heute', 'Gestern', 'Diese Woche', 'Diesen Monat', 'Älter'];

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
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Einstellungen',
            onPressed: _openPreferencesSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          const HeroHeader(
            metaLabel: 'Benachrichtigungen',
            title: 'Alles, was du nicht verpassen willst',
            subtitle:
                'Neue Nachrichten, Reaktionen auf deine Posts, akzeptierte Hilfsanfragen und mehr.',
            icon: Icons.notifications_active_outlined,
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filter == f.value;
                return ChoiceChip(
                  avatar: Icon(
                    f.icon,
                    size: 14,
                    color: selected ? AppColors.primary500 : AppColors.ink400,
                  ),
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _filter = f.value);
                    _load();
                  },
                  selectedColor: AppColors.primary500.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: selected ? AppColors.primary500 : AppColors.ink700,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          NewItemsBanner(
            count: newItemCount,
            singularLabel: 'Benachrichtigung',
            pluralLabel: 'Benachrichtigungen',
            onTap: _showNewItems,
            icon: Icons.notifications_active,
          ),
          Expanded(
            child: _loading
                ? const SkeletonList(count: 6)
                : _items.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          children: [
                            for (final key in groupOrder)
                              if (groups[key] != null) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: AppColors.ink400,
                                    ),
                                  ),
                                ),
                                ...groups[key]!.map(
                                  (n) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _NotificationTile(
                                      data: n,
                                      onTap: () => _open(n),
                                      onDelete: () =>
                                          _delete(n['id'] as String),
                                    ),
                                  ),
                                ),
                              ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      emoji: '🔕',
      title: 'Keine Benachrichtigungen',
      subtitle:
          'Hier erscheinen neue Mitteilungen aus der Community — Reaktionen, '
          'Erwähnungen und System-Updates.',
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.data,
    required this.onTap,
    required this.onDelete,
  });
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  bool get _isUnread {
    if (data['read'] == false) return true;
    if (data['read_at'] == null && data['read'] != true) return true;
    return false;
  }

  IconData _categoryIcon() {
    switch (data['category'] as String?) {
      case 'message':
        return Icons.chat_bubble_outline;
      case 'interaction':
        return Icons.handshake_outlined;
      case 'trust_rating':
        return Icons.star_outline;
      case 'post_nearby':
      case 'post_response':
        return Icons.location_on_outlined;
      case 'mention':
        return Icons.alternate_email;
      case 'bot':
        return Icons.smart_toy_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = data['actor'] as Map<String, dynamic>?;
    final actorName = actor?['name'] as String?;
    final actorAvatar = actor?['avatar_url'] as String?;
    final created = data['created_at'] as String?;
    final time = created != null
        ? DateFormat('HH:mm', 'de').format(DateTime.parse(created))
        : '';
    final title = data['title'] as String? ?? 'Benachrichtigung';
    final body = (data['body'] ?? data['content']) as String? ?? '';

    return Dismissible(
      key: ValueKey(data['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFB91C1C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Material(
        color: _isUnread
            ? AppColors.primary500.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (actorAvatar != null)
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(actorAvatar),
                  )
                else
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
                    child: Icon(
                      _categoryIcon(),
                      size: 18,
                      color: AppColors.primary500,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_isUnread)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary500,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: _isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              color: AppColors.ink400,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink700,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (actorName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          actorName,
                          style: const TextStyle(
                            color: AppColors.ink400,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.initial});
  final Map<String, dynamic> initial;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late final Map<String, bool> _values;

  static const _options = [
    (key: 'notify_new_messages', label: 'Neue Nachrichten', icon: Icons.message_outlined),
    (key: 'notify_new_interactions', label: 'Interaktionen', icon: Icons.handshake_outlined),
    (key: 'notify_nearby_posts', label: 'Posts in der Nähe', icon: Icons.near_me_outlined),
    (key: 'notify_trust_ratings', label: 'Trust-Bewertungen', icon: Icons.star_outline),
    (key: 'notify_system', label: 'System', icon: Icons.settings_outlined),
  ];
  static const _channels = [
    (key: 'notify_email', label: 'E-Mail', icon: Icons.email_outlined),
    (key: 'notify_push', label: 'Push', icon: Icons.notifications_outlined),
    (key: 'notify_sound', label: 'Sound', icon: Icons.volume_up_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _values = {
      for (final o in [..._options, ..._channels])
        o.key: (widget.initial[o.key] as bool?) ?? true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.stone300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Benachrichtigungen',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Worüber möchtest du informiert werden?',
                style: TextStyle(
                  color: AppColors.ink400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final o in _options)
                    SwitchListTile.adaptive(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      secondary: Icon(o.icon, color: AppColors.ink400),
                      title: Text(o.label),
                      value: _values[o.key] ?? true,
                      onChanged: (v) =>
                          setState(() => _values[o.key] = v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Wie möchtest du benachrichtigt werden?',
                style: TextStyle(
                  color: AppColors.ink400,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final c in _channels)
                    SwitchListTile.adaptive(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      secondary: Icon(c.icon, color: AppColors.ink400),
                      title: Text(c.label),
                      value: _values[c.key] ?? true,
                      onChanged: (v) =>
                          setState(() => _values[c.key] = v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_values),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Speichern',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
