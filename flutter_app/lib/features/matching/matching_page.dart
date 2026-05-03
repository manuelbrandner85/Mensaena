import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _Match {
  const _Match({
    required this.id,
    required this.matchScore,
    required this.status,
    required this.offerUserId,
    required this.requestUserId,
    required this.offerPostTitle,
    required this.requestPostTitle,
    required this.offerPostCategory,
    required this.requestPostCategory,
    this.conversationId,
    this.distanceKm,
    this.offerName,
    this.requestName,
    this.offerAvatar,
    this.requestAvatar,
  });

  final String id;
  final double matchScore;
  final String status;
  final String offerUserId;
  final String requestUserId;
  final String? offerPostTitle;
  final String? requestPostTitle;
  final String? offerPostCategory;
  final String? requestPostCategory;
  final String? conversationId;
  final double? distanceKm;
  final String? offerName;
  final String? requestName;
  final String? offerAvatar;
  final String? requestAvatar;

  factory _Match.fromJson(Map<String, dynamic> j) => _Match(
        id: j['id'] as String,
        matchScore: (j['match_score'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? 'suggested',
        offerUserId: j['offer_user_id'] as String? ?? '',
        requestUserId: j['request_user_id'] as String? ?? '',
        offerPostTitle: j['offer_post_title'] as String?,
        requestPostTitle: j['request_post_title'] as String?,
        offerPostCategory: j['offer_post_category'] as String?,
        requestPostCategory: j['request_post_category'] as String?,
        conversationId: j['conversation_id'] as String?,
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        offerName: j['offer_user_name'] as String?,
        requestName: j['request_user_name'] as String?,
        offerAvatar: j['offer_user_avatar'] as String?,
        requestAvatar: j['request_user_avatar'] as String?,
      );
}

// ── Page ──────────────────────────────────────────────────────────────────────

class MatchingPage extends ConsumerStatefulWidget {
  const MatchingPage({super.key});

  @override
  ConsumerState<MatchingPage> createState() => _MatchingPageState();
}

class _MatchingPageState extends ConsumerState<MatchingPage> {
  List<_Match> _matches = [];
  bool _loading = true;
  String _filter = 'all';
  String? _myId;
  String? _respondingId;

  static const _filters = [
    ('all', 'Alle'),
    ('suggested', 'Neu'),
    ('pending', 'Ausstehend'),
    ('accepted', 'Akzeptiert'),
  ];

  @override
  void initState() {
    super.initState();
    _myId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final db = ref.read(supabaseClientProvider);
      final data = await db.rpc('get_my_matches', queryParameters: {
        'p_status': _filter == 'all' ? null : _filter,
        'p_limit': 30,
        'p_offset': 0,
      });
      if (!mounted) return;
      final list = (data as List?)
              ?.map((e) => _Match.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      setState(() {
        _matches = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(String matchId, bool accept) async {
    HapticFeedback.mediumImpact();
    setState(() => _respondingId = matchId);
    try {
      final db = ref.read(supabaseClientProvider);
      final result = await db.rpc('respond_to_match', queryParameters: {
        'p_match_id': matchId,
        'p_accept': accept,
        'p_decline_reason': null,
      });
      if (!mounted) return;
      final convId = (result as Map?)?.tryGet<String>('conversation_id');
      if (accept && convId != null) {
        context.go('${Routes.dashboardChat}?conv=$convId');
        return;
      }
      if (accept) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zugestimmt – warte auf die andere Seite.')),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _respondingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Matching'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: _filters.map((f) {
                final selected = _filter == f.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.$2),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _filter = f.$1);
                      _load();
                    },
                    selectedColor: AppColors.primary500.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary500,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.primary500 : AppColors.ink700,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _matches.isEmpty
                    ? _EmptyState(filter: _filter)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _matches.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _MatchCard(
                            match: _matches[i],
                            myId: _myId ?? '',
                            respondingId: _respondingId,
                            onAccept: () => _respond(_matches[i].id, true),
                            onDecline: () => _respond(_matches[i].id, false),
                            onOpenChat: _matches[i].conversationId != null
                                ? () => context.go(
                                    '${Routes.dashboardChat}?conv=${_matches[i].conversationId}')
                                : null,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

extension on Map {
  T? tryGet<T>(String key) {
    final v = this[key];
    return v is T ? v : null;
  }
}

// ── Match card ────────────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.myId,
    required this.respondingId,
    required this.onAccept,
    required this.onDecline,
    this.onOpenChat,
  });

  final _Match match;
  final String myId;
  final String? respondingId;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onOpenChat;

  bool get _busy => respondingId == match.id;

  String get _statusLabel {
    switch (match.status) {
      case 'suggested':
        return 'Neu';
      case 'pending':
        return 'Ausstehend';
      case 'accepted':
        return 'Akzeptiert';
      case 'declined':
        return 'Abgelehnt';
      case 'expired':
        return 'Abgelaufen';
      default:
        return match.status;
    }
  }

  Color get _statusColor {
    switch (match.status) {
      case 'suggested':
        return AppColors.primary500;
      case 'pending':
        return Colors.amber.shade700;
      case 'accepted':
        return Colors.green.shade700;
      case 'declined':
      case 'expired':
        return AppColors.ink400;
      default:
        return AppColors.ink400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffer = match.offerUserId == myId;
    final myPost = isOffer ? match.offerPostTitle : match.requestPostTitle;
    final theirPost = isOffer ? match.requestPostTitle : match.offerPostTitle;
    final theirName = isOffer ? match.requestName : match.offerName;
    final theirAvatar = isOffer ? match.requestAvatar : match.offerAvatar;
    final initial = (theirName ?? '?').isNotEmpty ? (theirName ?? '?')[0].toUpperCase() : '?';
    final score = (match.matchScore * 100).round();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: avatar + name + score badge
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: theirAvatar != null ? NetworkImage(theirAvatar) : null,
                  backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
                  child: theirAvatar == null
                      ? Text(initial, style: const TextStyle(fontWeight: FontWeight.w600))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theirName ?? 'Unbekannt',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (match.distanceKm != null)
                        Text(
                          '${match.distanceKm!.toStringAsFixed(1)} km entfernt',
                          style: const TextStyle(color: AppColors.ink400, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                // Score chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$score%',
                    style: const TextStyle(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Posts
            _PostRow(label: 'Dein Post', title: myPost),
            const SizedBox(height: 4),
            _PostRow(label: 'Ihr Angebot', title: theirPost),
            // Actions
            if (match.status == 'suggested' || match.status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : onDecline,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        foregroundColor: AppColors.ink700,
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Ablehnen'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : onAccept,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary500),
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Akzeptieren'),
                    ),
                  ),
                ],
              ),
            ],
            if (match.status == 'accepted' && onOpenChat != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Chat öffnen'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.label, this.title});
  final String label;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(color: AppColors.ink400, fontSize: 12)),
        ),
        Expanded(
          child: Text(
            title ?? '–',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final String filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              filter == 'all'
                  ? 'Keine Matches gefunden'
                  : 'Keine Matches mit Status „$filter"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Erstelle Hilfe-Posts und vervollständige dein Profil,\num automatische Matches zu erhalten.',
              style: TextStyle(color: AppColors.ink400, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
