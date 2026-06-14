/// SKILL: mensaena-features
/// Freunde-Screen — Freundschaftsanfragen sind der zentrale, prominente
/// Bestandteil: eingehende Anfragen stehen GANZ OBEN als Hero-Sektion mit
/// großen Annehmen/Ablehnen-Buttons. Darunter: Freundesliste + Finden.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/conversations_repository.dart';
import '../../repositories/friendships_repository.dart';
import '../../services/haptics.dart';
import '../../services/presence_service.dart';
import '../../widgets/effects/celebrate_burst.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/error_state_widget.dart';
import '../../widgets/shared/sized_avatar_image.dart';
import '../../widgets/shared/user_picker_sheet.dart';

final _friendsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return FriendshipsRepository.friends();
});

final _incomingProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return FriendshipsRepository.incoming();
});

final _outgoingProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return FriendshipsRepository.outgoing();
});

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  String _search = '';
  String _findQuery = '';
  Timer? _searchDebounce;

  void _refreshAll() {
    ref.invalidate(_friendsProvider);
    ref.invalidate(_incomingProvider);
    ref.invalidate(_outgoingProvider);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _search = v.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(_friendsProvider);
    final incoming = ref.watch(_incomingProvider).value ?? const [];
    final outgoing = ref.watch(_outgoingProvider).value ?? const [];
    final onlineIds = ref.watch(onlineUsersProvider).value ?? const <String>{};
    final friends = friendsAsync.value ?? const [];

    return DashboardScaffold(
      title: 'friends.screenTitle'.tr(),
      currentRoute: '/dashboard/friends',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.bronze,
        foregroundColor: AppColors.voidColor,
        icon: const Icon(LucideIcons.userPlus, size: 18),
        label: Text(
          'friends.stateAdd'.tr(),
          style: AppTypography.label(
            size: 11,
            color: AppColors.voidColor,
            weight: FontWeight.w700,
          ),
        ),
        onPressed: () => UserPickerSheet.show(
          context,
          title: 'friends.tabFind'.tr(),
          pickedLabelKey: 'friends.requestSent',
          failedLabelKey: 'friends.requestFailed',
          onPick: (id, _) async {
            final ok = await FriendshipsRepository.request(id);
            if (ok) _refreshAll();
            return ok;
          },
        ),
      ),
      onRefresh: () async {
        _refreshAll();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            // ── HERO: Eingehende Anfragen (das wichtigste Element) ──────
            if (incoming.isNotEmpty) ...[
              _SectionHeader(
                icon: LucideIcons.userPlus,
                title: 'friends.incomingTitle'.tr(),
                count: incoming.length,
                accent: true,
              ),
              const SizedBox(height: 8),
              for (final r in incoming)
                _IncomingCard(row: r, onChanged: _refreshAll),
              const SizedBox(height: 18),
            ],

            // ── Gesendete Anfragen (kompakt) ───────────────────────────
            if (outgoing.isNotEmpty) ...[
              _SectionHeader(
                icon: LucideIcons.clock,
                title: 'friends.outgoingTitle'.tr(),
                count: outgoing.length,
              ),
              const SizedBox(height: 8),
              for (final r in outgoing)
                _OutgoingTile(row: r, onChanged: _refreshAll),
              const SizedBox(height: 18),
            ],

            // ── Finden: Suchfeld ───────────────────────────────────────
            _SectionHeader(
              icon: LucideIcons.search,
              title: 'friends.tabFind'.tr(),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce =
                    Timer(const Duration(milliseconds: 350), () {
                  if (mounted) setState(() => _findQuery = v.trim());
                });
              },
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'friends.findHint'.tr(),
                hintStyle: AppTypography.caption(),
                prefixIcon: const Icon(LucideIcons.search,
                    size: 16, color: AppColors.mute),
                filled: true,
                fillColor: AppColors.elevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
            if (_findQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SearchResults(query: _findQuery, onChanged: _refreshAll),
            ],
            const SizedBox(height: 18),

            // ── Freunde ────────────────────────────────────────────────
            _SectionHeader(
              icon: LucideIcons.users,
              title: 'friends.tabAll'.tr(),
              count: friends.isEmpty ? null : friends.length,
            ),
            const SizedBox(height: 8),
            if (friends.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  onChanged: _onSearchChanged,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'friends.searchHint'.tr(),
                    hintStyle: AppTypography.caption(),
                    prefixIcon: const Icon(LucideIcons.search,
                        size: 16, color: AppColors.mute),
                    filled: true,
                    fillColor: AppColors.elevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            friendsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.bronze)),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ErrorStateWidget(
                  compact: true,
                  onRetry: () => ref.invalidate(_friendsProvider),
                ),
              ),
              data: (rows) => _FriendsList(
                rows: rows,
                onlineIds: onlineIds,
                search: _search,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.count,
    this.accent = false,
  });
  final IconData icon;
  final String title;
  final int? count;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? AppColors.bronze : AppColors.inkSoft;
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(title.toUpperCase(),
            style: AppTypography.label(size: 10, color: color)),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: accent
                  ? AppColors.bronze
                  : AppColors.elevated,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count',
                style: AppTypography.label(
                    size: 10,
                    color: accent ? AppColors.voidColor : AppColors.inkSoft,
                    weight: FontWeight.w800)),
          ),
        ],
      ],
    );
  }
}

/// Große, prominente Karte für eine eingehende Anfrage.
class _IncomingCard extends StatefulWidget {
  const _IncomingCard({required this.row, required this.onChanged});
  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  @override
  State<_IncomingCard> createState() => _IncomingCardState();
}

class _IncomingCardState extends State<_IncomingCard> {
  bool _busy = false;

  Future<void> _decide(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    final requesterId = widget.row['requester_id'] as String;
    Haptics.tap();
    final ok = accept
        ? await FriendshipsRepository.accept(requesterId)
        : await FriendshipsRepository.decline(requesterId);
    if (!mounted) return;
    if (ok && accept) CelebrateBurst.fire(context);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = (widget.row['profiles'] as Map?) ?? const {};
    final id = p['id'] as String?;
    final name = (p['display_name'] as String?) ?? 'common.neighbour'.tr();
    final avatar = p['avatar_url'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bronze.withValues(alpha: 0.14),
            AppColors.surface.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: id == null
                    ? null
                    : () => context.push('/dashboard/profile/$id'),
                child:
                    SizedAvatarImage(url: avatar, size: 48, fallbackInitial: name),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                            size: 15,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                    Text('friends.wantsToConnect'.tr(),
                        style: AppTypography.caption()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _decide(true),
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.voidColor))
                      : const Icon(LucideIcons.userCheck, size: 16),
                  label: Text('friends.stateAccept'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.leben,
                    foregroundColor: AppColors.voidColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _decide(false),
                icon: const Icon(LucideIcons.x, size: 16),
                label: Text('common.reject'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mute,
                  side: const BorderSide(color: AppColors.line),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutgoingTile extends StatelessWidget {
  const _OutgoingTile({required this.row, required this.onChanged});
  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final p = (row['profiles'] as Map?) ?? const {};
    final name = (p['display_name'] as String?) ?? 'common.neighbour'.tr();
    final avatar = p['avatar_url'] as String?;
    final addresseeId = row['addressee_id'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.35),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedAvatarImage(url: avatar, size: 36, fallbackInitial: name),
          const SizedBox(width: 10),
          Expanded(
            child: Text('friends.stateRequestedTo'.tr(namedArgs: {'name': name}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
          ),
          TextButton(
            onPressed: () async {
              if (addresseeId == null) return;
              await FriendshipsRepository.remove(addresseeId);
              onChanged();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
            ),
            child: Text('friends.cancelRequest'.tr(),
                style: AppTypography.label(size: 10, color: AppColors.mute)),
          ),
        ],
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList({
    required this.rows,
    required this.onlineIds,
    required this.search,
  });
  final List<Map<String, dynamic>> rows;
  final Set<String> onlineIds;
  final String search;

  @override
  Widget build(BuildContext context) {
    final filtered = rows.where((p) {
      if (search.isEmpty) return true;
      final name = ((p['display_name'] as String?) ??
              (p['name'] as String?) ??
              '')
          .toLowerCase();
      return name.contains(search);
    }).toList();
    filtered.sort((a, b) {
      final ao = onlineIds.contains(a['id'] as String?) ? 0 : 1;
      final bo = onlineIds.contains(b['id'] as String?) ? 0 : 1;
      if (ao != bo) return ao - bo;
      return ((a['display_name'] as String?) ?? '')
          .compareTo((b['display_name'] as String?) ?? '');
    });
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(LucideIcons.users, size: 40, color: AppColors.mute),
            const SizedBox(height: 10),
            Text('friends.noFriends'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 13, color: AppColors.mute)),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final p in filtered)
          _FriendTile(
            p: p,
            isOnline: onlineIds.contains(p['id'] as String?),
          ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.p, required this.isOnline});
  final Map<String, dynamic> p;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final id = p['id'] as String;
    final name = (p['display_name'] as String?) ??
        (p['name'] as String?) ??
        'common.neighbour'.tr();
    final avatar = p['avatar_url'] as String?;
    return InkWell(
      onTap: () => context.push('/dashboard/profile/$id'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Stack(children: [
            SizedAvatarImage(url: avatar, size: 44, fallbackInitial: name),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.leben,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                    size: 14, color: AppColors.ink, weight: FontWeight.w600)),
          ),
          IconButton(
            tooltip: 'friends.chatTooltip'.tr(),
            icon: const Icon(LucideIcons.messageSquare,
                size: 18, color: AppColors.bronze),
            onPressed: () async {
              final convId = await ConversationsRepository.getOrCreateDm(id);
              if (convId != null && context.mounted) {
                context.push('/dashboard/messages/$convId');
              }
            },
          ),
        ]),
      ),
    );
  }
}

/// Such-Ergebnisse beim Finden neuer Leute, inline unter dem Suchfeld.
class _SearchResults extends StatefulWidget {
  const _SearchResults({required this.query, required this.onChanged});
  final String query;
  final VoidCallback onChanged;

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  Future<List<Map<String, dynamic>>>? _future;
  String _last = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_SearchResults old) {
    super.didUpdateWidget(old);
    if (widget.query != _last) _load();
  }

  void _load() {
    _last = widget.query;
    setState(() {
      _future = widget.query.isEmpty
          ? Future.value(const [])
          : FriendshipsRepository.searchUsers(widget.query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.bronze)),
          );
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('friends.findNoResults'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.body(size: 13, color: AppColors.mute)),
          );
        }
        return Column(
          children: [
            for (final row in rows)
              _SearchResultTile(
                row: row,
                onChanged: () {
                  widget.onChanged();
                  _load();
                },
              ),
          ],
        );
      },
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  const _SearchResultTile({required this.row, required this.onChanged});
  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
  bool _busy = false;
  late String _state = widget.row['friendship_state'] as String? ?? 'none';

  Future<void> _act() async {
    final id = widget.row['id'] as String;
    setState(() => _busy = true);
    bool ok = false;
    switch (_state) {
      case 'none':
      case 'declined':
        ok = await FriendshipsRepository.request(id);
        if (ok) _state = 'outgoingPending';
        break;
      case 'incomingPending':
        ok = await FriendshipsRepository.accept(id);
        if (ok) _state = 'accepted';
        break;
      case 'outgoingPending':
        ok = await FriendshipsRepository.remove(id);
        if (ok) _state = 'none';
        break;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.row['id'] as String;
    final name = (widget.row['display_name'] as String?) ??
        (widget.row['name'] as String?) ??
        'common.neighbour'.tr();
    final avatar = widget.row['avatar_url'] as String?;

    final (String label, IconData icon, Color color) = switch (_state) {
      'accepted' =>
        ('friends.stateFriends'.tr(), LucideIcons.check, AppColors.leben),
      'outgoingPending' =>
        ('friends.stateRequested'.tr(), LucideIcons.clock, AppColors.mute),
      'incomingPending' => (
          'friends.stateAccept'.tr(),
          LucideIcons.userCheck,
          AppColors.bronze
        ),
      _ => ('friends.stateAdd'.tr(), LucideIcons.userPlus, AppColors.bronze),
    };
    final isInteractive = _state != 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        InkWell(
          onTap: () => context.push('/dashboard/profile/$id'),
          child: SizedAvatarImage(url: avatar, size: 44, fallbackInitial: name),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => context.push('/dashboard/profile/$id'),
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                    size: 14, color: AppColors.ink, weight: FontWeight.w600)),
          ),
        ),
        if (_busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.bronze),
          )
        else
          TextButton.icon(
            onPressed: isInteractive ? _act : null,
            icon: Icon(icon, size: 16, color: color),
            label: Text(label,
                style: AppTypography.body(size: 12, color: color)),
          ),
      ]),
    );
  }
}
