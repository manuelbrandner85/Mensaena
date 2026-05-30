/// SKILL: mensaena-features (Phase 6 ZUSATZ-4F)
/// Friends-Screen mit 3 Tabs (Alle / Online / Kürzlich + eingehende Anfragen).
/// Online-Status nutzt presence_service. Suche filtert nach display_name.
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
import '../../services/presence_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/sized_avatar_image.dart';
import '../../widgets/shared/user_picker_sheet.dart';

final _friendsProvider = FutureProvider.autoDispose<
    List<Map<String, dynamic>>>((ref) async {
  return FriendshipsRepository.friends();
});

final _incomingProvider = FutureProvider.autoDispose<
    List<Map<String, dynamic>>>((ref) async {
  return FriendshipsRepository.incoming();
});

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _search = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      // Such-Hint je nach Tab aktualisieren (Rebuild).
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tab.dispose();
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
    final incomingAsync = ref.watch(_incomingProvider);
    final onlineIds = ref.watch(onlineUsersProvider).value ?? const <String>{};

    return DashboardScaffold(
      title: 'friends.screenTitle'.tr(),
      currentRoute: '/dashboard/friends',
      // Sichtbarer 1-Tap-Einstieg zur User-Suche → Freundschaftsanfrage.
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
          onPick: (id, _) => FriendshipsRepository.request(id),
        ),
      ),
      onRefresh: () async {
        ref.invalidate(_friendsProvider);
        ref.invalidate(_incomingProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: AppColors.bronze.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.bronze.withValues(alpha: 0.5)),
                ),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.bronze,
                unselectedLabelColor: AppColors.inkSoft,
                labelStyle: AppTypography.body(
                    size: 12, weight: FontWeight.w700),
                unselectedLabelStyle: AppTypography.body(size: 12),
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                tabs: [
                  Tab(text: 'friends.tabAll'.tr()),
                  Tab(text: 'friends.tabOnline'.tr()),
                  Tab(text: 'friends.tabRequests'.tr()),
                  Tab(text: 'friends.tabFind'.tr()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextField(
                onChanged: _onSearchChanged,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: _tab.index == 3
                      ? 'friends.findHint'.tr()
                      : 'friends.searchHint'.tr(),
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
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _FriendsList(
                    async: friendsAsync,
                    onlineIds: onlineIds,
                    search: _search,
                  ),
                  _FriendsList(
                    async: friendsAsync,
                    onlineIds: onlineIds,
                    search: _search,
                    onlineOnly: true,
                  ),
                  _IncomingList(async: incomingAsync, search: _search),
                  _SearchAddList(
                    query: _search,
                    onChanged: () {
                      ref.invalidate(_friendsProvider);
                      ref.invalidate(_incomingProvider);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList({
    required this.async,
    required this.onlineIds,
    required this.search,
    this.onlineOnly = false,
  });
  final AsyncValue<List<Map<String, dynamic>>> async;
  final Set<String> onlineIds;
  final String search;
  final bool onlineOnly;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.bronze)),
      error: (e, _) => Center(child: Text('$e', style: AppTypography.caption())),
      data: (rows) {
        final filtered = rows.where((p) {
          final id = p['id'] as String?;
          if (onlineOnly && (id == null || !onlineIds.contains(id))) {
            return false;
          }
          if (search.isEmpty) return true;
          final name = ((p['display_name'] as String?) ??
                  (p['name'] as String?) ??
                  '')
              .toLowerCase();
          return name.contains(search);
        }).toList();
        // Online zuerst.
        filtered.sort((a, b) {
          final ao = onlineIds.contains(a['id'] as String?) ? 0 : 1;
          final bo = onlineIds.contains(b['id'] as String?) ? 0 : 1;
          if (ao != bo) return ao - bo;
          final an = (a['display_name'] as String?) ?? '';
          final bn = (b['display_name'] as String?) ?? '';
          return an.compareTo(bn);
        });
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.users,
                      size: 40, color: AppColors.mute),
                  const SizedBox(height: 10),
                  Text(
                    onlineOnly
                        ? 'friends.noOnline'.tr()
                        : 'friends.noFriends'.tr(),
                    style: AppTypography.body(
                        size: 13, color: AppColors.mute),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _FriendTile(
            p: filtered[i],
            isOnline: onlineIds.contains(filtered[i]['id'] as String?),
          ),
        );
      },
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Stack(children: [
            SizedAvatarImage(
              url: avatar,
              size: 44,
              fallbackInitial: name,
            ),
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
                    border: Border.all(
                        color: AppColors.surface, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                  weight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'friends.chatTooltip'.tr(),
            icon: const Icon(LucideIcons.messageSquare,
                size: 18, color: AppColors.bronze),
            onPressed: () async {
              final convId =
                  await ConversationsRepository.getOrCreateDm(id);
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

class _IncomingList extends ConsumerWidget {
  const _IncomingList({required this.async, required this.search});
  final AsyncValue<List<Map<String, dynamic>>> async;
  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.bronze)),
      error: (e, _) => Center(child: Text('$e', style: AppTypography.caption())),
      data: (rows) {
        final filtered = rows.where((r) {
          if (search.isEmpty) return true;
          final p = (r['profiles'] as Map?) ?? const {};
          final name =
              (p['display_name'] as String? ?? '').toLowerCase();
          return name.contains(search);
        }).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('friends.noRequests'.tr(),
                  style: AppTypography.body(
                      size: 13, color: AppColors.mute),
                  textAlign: TextAlign.center),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _IncomingTile(row: filtered[i]),
        );
      },
    );
  }
}

class _IncomingTile extends ConsumerWidget {
  const _IncomingTile({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requesterId = row['requester_id'] as String;
    final p = (row['profiles'] as Map?) ?? const {};
    final name = (p['display_name'] as String?) ??
        'common.neighbour'.tr();
    final avatar = p['avatar_url'] as String?;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        SizedAvatarImage(url: avatar, size: 44, fallbackInitial: name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w600)),
              Text('friends.wantsToConnect'.tr(),
                  style: AppTypography.caption()),
            ],
          ),
        ),
        IconButton(
          tooltip: 'common.confirm'.tr(),
          icon: const Icon(LucideIcons.check,
              size: 20, color: AppColors.leben),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await FriendshipsRepository.accept(requesterId);
            ref.invalidate(_incomingProvider);
            ref.invalidate(_friendsProvider);
            messenger.showSnackBar(SnackBar(
              backgroundColor: AppColors.surface,
              content: Text('friends.requestAccepted'.tr(),
                  style: AppTypography.body(size: 13, color: AppColors.ink)),
            ));
          },
        ),
        IconButton(
          tooltip: 'common.reject'.tr(),
          icon: const Icon(LucideIcons.x,
              size: 20, color: AppColors.herzrotWarm),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await FriendshipsRepository.decline(requesterId);
            ref.invalidate(_incomingProvider);
            messenger.showSnackBar(SnackBar(
              backgroundColor: AppColors.surface,
              content: Text('friends.requestDeclined'.tr(),
                  style: AppTypography.body(size: 13, color: AppColors.ink)),
            ));
          },
        ),
      ]),
    );
  }
}

/// Tab "Finden": globale User-Suche + zustandsabhängiger Aktions-Button
/// (Anfragen / Angefragt / Annehmen / Befreundet).
class _SearchAddList extends StatefulWidget {
  const _SearchAddList({required this.query, required this.onChanged});
  final String query;
  final VoidCallback onChanged;

  @override
  State<_SearchAddList> createState() => _SearchAddListState();
}

class _SearchAddListState extends State<_SearchAddList> {
  Future<List<Map<String, dynamic>>>? _future;
  String _lastQuery = '';

  @override
  void didUpdateWidget(_SearchAddList old) {
    super.didUpdateWidget(old);
    if (widget.query != _lastQuery) {
      _lastQuery = widget.query;
      // setState damit der FutureBuilder den neuen Future garantiert
      // aufnimmt — vorheriges nur-Zuweisen hat den Rebuild verpasst.
      setState(() {
        _future = widget.query.trim().isEmpty
            ? Future.value(const [])
            : FriendshipsRepository.searchUsers(widget.query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.userPlus, size: 40, color: AppColors.mute),
              const SizedBox(height: 10),
              Text('friends.findPrompt'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 13, color: AppColors.mute)),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.bronze));
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('friends.findNoResults'.tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.body(size: 13, color: AppColors.mute)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) => _SearchResultTile(
            row: rows[i],
            onChanged: () {
              widget.onChanged();
              // Such-Ergebnis neu laden damit der Button-Status stimmt.
              setState(() {
                _future = FriendshipsRepository.searchUsers(widget.query);
              });
            },
          ),
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
      'accepted' => ('friends.stateFriends'.tr(), LucideIcons.check,
          AppColors.leben),
      'outgoingPending' => ('friends.stateRequested'.tr(),
          LucideIcons.clock, AppColors.mute),
      'incomingPending' => ('friends.stateAccept'.tr(),
          LucideIcons.userCheck, AppColors.bronze),
      _ => ('friends.stateAdd'.tr(), LucideIcons.userPlus, AppColors.bronze),
    };
    final isInteractive = _state != 'accepted';

    return Container(
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
