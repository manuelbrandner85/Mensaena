import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import '../messages/messages_repository.dart';
import '../messages/models.dart' as messages_models;
import 'models.dart';
import 'outgoing_call_page.dart';

/// Anrufhistorie – Pendant zu src/components/chat/CallHistory.tsx.
/// Zeigt die letzten 30 Calls (caller_id ODER callee_id == userId).
class CallHistoryPage extends ConsumerStatefulWidget {
  const CallHistoryPage({super.key});

  @override
  ConsumerState<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends ConsumerState<CallHistoryPage> {
  bool _loading = true;
  String? _error;
  List<_CallRecord> _records = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = sb.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Nicht eingeloggt';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await sb
          .from('dm_calls')
          .select(
            'id, conversation_id, caller_id, callee_id, call_type, '
            'status, created_at, answered_at, ended_at, room_name',
          )
          .or('caller_id.eq.${user.id},callee_id.eq.${user.id}')
          .order('created_at', ascending: false)
          .limit(30);
      final calls = List<Map<String, dynamic>>.from(rows);
      if (calls.isEmpty) {
        if (!mounted) return;
        setState(() {
          _records = const [];
          _loading = false;
        });
        return;
      }
      final partnerIds = <String>{
        for (final c in calls)
          (c['caller_id'] == user.id ? c['callee_id'] : c['caller_id'])
              as String,
      }.toList();
      final profiles = await sb
          .from('profiles')
          .select('id, name, avatar_url')
          .inFilter('id', partnerIds);
      final profileMap = <String, Map<String, dynamic>>{
        for (final p in List<Map<String, dynamic>>.from(profiles))
          p['id'] as String: p,
      };
      final records = calls.map((c) {
        final isOutgoing = c['caller_id'] == user.id;
        final partnerId =
            (isOutgoing ? c['callee_id'] : c['caller_id']) as String;
        final profile = profileMap[partnerId];
        return _CallRecord(
          id: c['id'] as String,
          conversationId: c['conversation_id'] as String,
          partnerId: partnerId,
          partnerName: profile?['name'] as String? ?? 'Unbekannt',
          partnerAvatar: profile?['avatar_url'] as String?,
          callType: (c['call_type'] as String?) == 'video'
              ? DmCallType.video
              : DmCallType.audio,
          status: c['status'] as String? ?? 'unknown',
          isOutgoing: isOutgoing,
          createdAt: DateTime.parse(c['created_at'] as String),
          answeredAt: c['answered_at'] != null
              ? DateTime.tryParse(c['answered_at'] as String)
              : null,
          endedAt: c['ended_at'] != null
              ? DateTime.tryParse(c['ended_at'] as String)
              : null,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _callBack(_CallRecord r) async {
    final myId = sb.auth.currentUser?.id;
    if (myId == null) return;
    try {
      final convId = await ref
          .read(messagesRepositoryProvider)
          .findOrCreateDirectConversation(userA: myId, userB: r.partnerId);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OutgoingCallPage(
            conversationId: convId,
            callee: messages_models.Profile(
              id: r.partnerId,
              name: r.partnerName,
              avatarUrl: r.partnerAvatar,
            ),
            callType: r.callType,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anruf fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.history, size: 20, color: AppColors.primary500),
            SizedBox(width: 8),
            Text('Letzte Anrufe'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline,
              size: 48, color: AppColors.emergency500),
          const SizedBox(height: 12),
          Center(child: Text(_error!)),
          Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('Erneut versuchen'),
            ),
          ),
        ],
      );
    }
    if (_records.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.phone_disabled, size: 48, color: AppColors.stone300),
          SizedBox(height: 12),
          Center(
            child: Text(
              'Noch keine Anrufe',
              style: TextStyle(color: AppColors.stone500),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: _records.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 76, color: Color(0xFFEFEFEF)),
      itemBuilder: (_, i) {
        final r = _records[i];
        return _CallTile(record: r, onCall: () => _callBack(r));
      },
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.record, required this.onCall});
  final _CallRecord record;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final isMissed = r.status == 'missed';
    final isDeclined = r.status == 'declined';
    final isEnded = r.status == 'ended';

    IconData arrow;
    Color arrowColor;
    if (isMissed) {
      arrow = Icons.call_missed;
      arrowColor = AppColors.emergency500;
    } else if (r.isOutgoing) {
      arrow = Icons.call_made;
      arrowColor = AppColors.stone400;
    } else {
      arrow = Icons.call_received;
      arrowColor = const Color(0xFF22C55E);
    }

    String statusLabel;
    if (isMissed) {
      statusLabel = 'Verpasst';
    } else if (isDeclined) {
      statusLabel = 'Abgelehnt';
    } else if (isEnded && r.duration != null) {
      statusLabel = r.duration!;
    } else if (r.status == 'cancelled') {
      statusLabel = 'Abgebrochen';
    } else {
      statusLabel = r.status;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary100,
        backgroundImage: r.partnerAvatar != null
            ? NetworkImage(r.partnerAvatar!)
            : null,
        child: r.partnerAvatar == null
            ? Text(
                r.partnerName.isNotEmpty
                    ? r.partnerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary700,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      title: Text(
        r.partnerName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isMissed ? AppColors.emergency500 : AppColors.ink800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Icon(arrow, size: 14, color: arrowColor),
            const SizedBox(width: 4),
            Text(
              statusLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.stone500,
              ),
            ),
            const SizedBox(width: 6),
            const Text('·', style: TextStyle(color: AppColors.stone300)),
            const SizedBox(width: 6),
            Text(
              _formatTime(r.createdAt),
              style:
                  const TextStyle(fontSize: 12, color: AppColors.stone500),
            ),
            if (r.callType == DmCallType.video) ...[
              const SizedBox(width: 6),
              const Icon(Icons.videocam,
                  size: 14, color: AppColors.stone400),
            ],
          ],
        ),
      ),
      trailing: IconButton(
        onPressed: onCall,
        icon: const Icon(Icons.phone, color: AppColors.primary500),
        tooltip: '${r.partnerName} anrufen',
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays < 1) return DateFormat('HH:mm').format(t);
    if (diff.inDays < 7) {
      return '${DateFormat.E('de').format(t)} ${DateFormat('HH:mm').format(t)}';
    }
    return DateFormat('dd.MM. HH:mm').format(t);
  }
}

class _CallRecord {
  _CallRecord({
    required this.id,
    required this.conversationId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    required this.callType,
    required this.status,
    required this.isOutgoing,
    required this.createdAt,
    required this.answeredAt,
    required this.endedAt,
  });

  final String id;
  final String conversationId;
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;
  final DmCallType callType;
  final String status;
  final bool isOutgoing;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  String? get duration {
    if (answeredAt == null || endedAt == null) return null;
    final secs = endedAt!.difference(answeredAt!).inSeconds;
    if (secs <= 0) return null;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
