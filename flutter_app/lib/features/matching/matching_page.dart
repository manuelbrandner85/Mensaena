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
    _myId = ref.read(supabaseProvider).auth.currentUser?.id;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final db = ref.read(supabaseProvider);
      final data = await db.rpc<List<dynamic>>(
        'get_my_matches',
        params: <String, dynamic>{
          'p_status': _filter == 'all' ? null : _filter,
          'p_limit': 30,
          'p_offset': 0,
        },
      );
      if (!mounted) return;
      final list = data
          .map((e) => _Match.fromJson(e as Map<String, dynamic>))
          .toList();
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
      final db = ref.read(supabaseProvider);
      final result = await db.rpc<Map<String, dynamic>>(
        'respond_to_match',
        params: <String, dynamic>{
          'p_match_id': matchId,
          'p_accept': accept,
          'p_decline_reason': null,
        },
      );
      if (!mounted) return;
      final convId = result['conversation_id'] as String?;
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

  Future<void> _openPreferences() async {
    final db = ref.read(supabaseProvider);
    final user = db.auth.currentUser;
    if (user == null) return;
    Map<String, dynamic>? current;
    try {
      current = await db
          .from('match_preferences')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();
    } catch (_) {
      current = null;
    }
    if (!mounted) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scroll) =>
            _PreferencesSheet(initial: current ?? const {}, scroll: scroll),
      ),
    );
    if (updated == null) return;
    HapticFeedback.mediumImpact();
    try {
      await db.from('match_preferences').upsert(<String, dynamic>{
        'user_id': user.id,
        ...updated,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match-Einstellungen gespeichert')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
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
            icon: const Icon(Icons.tune),
            tooltip: 'Match-Einstellungen',
            onPressed: _openPreferences,
          ),
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
                                    '${Routes.dashboardChat}?conv=${_matches[i].conversationId}',
                                  )
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

// ─── Preferences-Sheet ───────────────────────────────────────────────────────

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.initial, required this.scroll});
  final Map<String, dynamic> initial;
  final ScrollController scroll;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late bool _enabled = (widget.initial['matching_enabled'] as bool?) ?? true;
  late double _maxDistance =
      (widget.initial['max_distance_km'] as num?)?.toDouble() ?? 25;
  late int _maxPerDay =
      (widget.initial['max_matches_per_day'] as num?)?.toInt() ?? 5;
  late double _minTrust =
      (widget.initial['min_trust_score'] as num?)?.toDouble() ?? 0;
  late bool _notify = (widget.initial['notify_on_match'] as bool?) ?? true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Match-Einstellungen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: const Text('Matching aktiv',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                      'Bekommst du automatische Matching-Vorschläge?',
                      style: TextStyle(color: AppColors.ink400, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PrefCard(
                  title: 'Max. Entfernung',
                  trailing: '${_maxDistance.toStringAsFixed(0)} km',
                  child: Slider(
                    value: _maxDistance,
                    min: 1,
                    max: 200,
                    divisions: 199,
                    activeColor: AppColors.primary500,
                    onChanged: _enabled
                        ? (v) => setState(() => _maxDistance = v)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                _PrefCard(
                  title: 'Max. Vorschläge pro Tag',
                  trailing: '$_maxPerDay',
                  child: Slider(
                    value: _maxPerDay.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    activeColor: AppColors.primary500,
                    onChanged: _enabled
                        ? (v) => setState(() => _maxPerDay = v.toInt())
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                _PrefCard(
                  title: 'Min. Trust-Score',
                  trailing: _minTrust > 0
                      ? '⭐ ${_minTrust.toStringAsFixed(1)}'
                      : 'kein Filter',
                  child: Slider(
                    value: _minTrust,
                    min: 0,
                    max: 5,
                    divisions: 10,
                    activeColor: AppColors.primary500,
                    onChanged: _enabled
                        ? (v) => setState(() => _minTrust = v)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _notify,
                    onChanged: _enabled
                        ? (v) => setState(() => _notify = v)
                        : null,
                    title: const Text('Bei neuem Match benachrichtigen',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                      'Push + In-App-Notification',
                      style: TextStyle(color: AppColors.ink400, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(<String, dynamic>{
                      'matching_enabled': _enabled,
                      'max_distance_km': _maxDistance,
                      'max_matches_per_day': _maxPerDay,
                      'min_trust_score': _minTrust,
                      'notify_on_match': _notify,
                    }),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Speichern'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefCard extends StatelessWidget {
  const _PrefCard({
    required this.title,
    required this.trailing,
    required this.child,
  });
  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
