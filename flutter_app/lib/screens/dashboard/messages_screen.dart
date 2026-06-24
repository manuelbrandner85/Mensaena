import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../config/theme/cinema_accents.dart';
import '../../providers/cinema_provider.dart';
import '../../providers/conversation_mute_ids_provider.dart';
import '../../providers/unread_counts_provider.dart';
import '../../widgets/chat/chat_recap_sheet.dart';
import '../../config/routes/app_router.dart' show rootNavigatorKey;
import '../../repositories/conversations_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/haptics.dart';
import '../../services/presence_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/effects/animated_entrance.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/sized_avatar_image.dart';
import '../../widgets/shared/error_state_card.dart';
import '../../widgets/effects/shimmer_skeleton.dart';

/// SKILL: mensaena-features
/// Chat-Hub: 2 Tabs — Community (Channels gruppiert nach Kategorie)
/// + Nachrichten (Direct Messages + Groups). 1:1 zu Web ChatView.tsx.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key, this.initialTab = 0});

  /// 0 = Community (Channels), 1 = Nachrichten (DMs).
  /// /dashboard/chat → 0, /dashboard/messages → 1.
  final int initialTab;

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  Future<List<Map<String, dynamic>>>? _convs;
  Future<List<Map<String, dynamic>>>? _channels;
  String _searchDm = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _load() {
    _convs = ConversationsRepository.listMine();
    _channels = ConversationsRepository.listChannels();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_convs!, _channels!]);
  }

  /// F2c: User-Picker fuer neue DM. Sucht in profiles, tap → get_or_create_dm.
  Future<void> _openNewDmPicker(BuildContext context) async {
    Haptics.tap();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) =>
            _NewDmPickerSheet(scrollCtrl: scrollCtrl),
      ),
    );
  }

  /// „Raum erstellen" — Förderer:innen (donor_tier>=2) legen einen Community-
  /// Kanal an (Name + Emoji + optionale Beschreibung).
  Future<void> _openCreateChannel(BuildContext context) async {
    Haptics.tap();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    const emojis = [
      '💬', '🏘️', '🌿', '🤝', '🎉', '📢', '🛒', '📚', '🌍', '🍽️', '🐾', '💡'
    ];
    var emoji = '💬';
    var isPrivate = false;
    var busy = false;
    final messenger = ScaffoldMessenger.of(context);
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('chat.createChannelTitle'.tr(),
                  style: AppTypography.display(size: 18, color: AppColors.ink)),
              const SizedBox(height: 2),
              Text('chat.createChannelSubtitle'.tr(),
                  style: AppTypography.caption()),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in emojis)
                    GestureDetector(
                      onTap: () => setSheet(() => emoji = e),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: emoji == e
                              ? AppColors.amber.withValues(alpha: 0.2)
                              : AppColors.elevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  emoji == e ? AppColors.amber : AppColors.line),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                maxLength: 40,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'chat.channelNameLabel'.tr(),
                  hintText: 'chat.channelNameHint'.tr(),
                  prefixIcon: const Icon(LucideIcons.hash, size: 16),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLength: 120,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'chat.channelDescLabel'.tr(),
                  hintText: 'chat.channelDescHint'.tr(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: catCtrl,
                maxLength: 30,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'chat.channelCategoryLabel'.tr(),
                  hintText: 'chat.channelCategoryHint'.tr(),
                  prefixIcon: const Icon(LucideIcons.tag, size: 16),
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.amber,
                value: isPrivate,
                onChanged: (v) => setSheet(() => isPrivate = v),
                secondary: Icon(
                    isPrivate ? LucideIcons.lock : LucideIcons.globe,
                    size: 18, color: AppColors.bronze),
                title: Text('chat.channelPrivate'.tr(),
                    style: AppTypography.body(size: 14, color: AppColors.ink)),
                subtitle: Text(
                    isPrivate
                        ? 'chat.channelPrivateHint'.tr()
                        : 'chat.channelPublicHint'.tr(),
                    style:
                        AppTypography.body(size: 11, color: AppColors.inkSoft)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.voidColor,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: busy
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setSheet(() => busy = true);
                          final ch =
                              await ConversationsRepository.createChannel(
                            name: nameCtrl.text,
                            emoji: emoji,
                            description: descCtrl.text,
                            category: catCtrl.text.trim().isEmpty
                                ? 'Community'
                                : catCtrl.text.trim(),
                            isPrivate: isPrivate,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, ch != null);
                        },
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.voidColor),
                        )
                      : const Icon(LucideIcons.plus, size: 16),
                  label: Text('chat.createChannelCta'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
    catCtrl.dispose();
    if (!mounted) return;
    if (created == true) {
      setState(_load);
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('chat.channelCreated'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    } else if (created == false) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('chat.createChannelFailed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myTier = ref.watch(myProfileProvider).value?.donorTier ?? 0;
    return DashboardScaffold(
      title: 'messages.title'.tr(),
      currentRoute: '/dashboard/messages',
      // FAB: DM-Tab → "Neue DM"; Community-Tab → "Raum erstellen"
      // (nur Förderer:innen, donor_tier>=2; serverseitig per RLS erzwungen).
      fab: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) {
          if (_tab.index == 1) {
            return FloatingActionButton(
              backgroundColor: AppColors.bronze,
              foregroundColor: AppColors.voidColor,
              tooltip: 'messages.newDm'.tr(),
              onPressed: () => _openNewDmPicker(context),
              child: const Icon(LucideIcons.messageSquarePlus, size: 24),
            );
          }
          if (_tab.index == 0 && myTier >= 2) {
            return FloatingActionButton.extended(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.voidColor,
              tooltip: 'chat.createChannel'.tr(),
              onPressed: () => _openCreateChannel(context),
              icon: const Icon(LucideIcons.plus, size: 20),
              label: Text('chat.createChannel'.tr()),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tab-Bar Community | Nachrichten
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
                tabs: [
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.hash, size: 14),
                        const SizedBox(width: 6),
                        Text('chat.communityTab'.tr()),
                      ],
                    ),
                  ),
                  Tab(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.mail, size: 14),
                        const SizedBox(width: 6),
                        Text('chat.dmTab'.tr()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // BUG-FIX #7: RefreshIndicator in EINZELNE Tab-Children,
              // nicht ueber TabBarView — sonst kollidiert Pull-Gesture
              // mit Tab-Swipe.
              child: TabBarView(
                controller: _tab,
                children: [
                  RefreshIndicator(
                    color: AppColors.amber,
                    backgroundColor: AppColors.surface,
                    onRefresh: _refresh,
                    child: _ChannelListView(
                      future: _channels,
                      onChanged: () => setState(_load),
                    ),
                  ),
                  RefreshIndicator(
                    color: AppColors.amber,
                    backgroundColor: AppColors.surface,
                    onRefresh: _refresh,
                    child: _DmListView(
                      future: _convs,
                      search: _searchDm,
                      onSearchChanged: (v) => setState(() => _searchDm = v),
                      onlineUserIds: ref
                              .watch(onlineUsersProvider)
                              .value ??
                          const <String>{},
                      // F1c-Fix: nach Hide/Delete eigene _convs neu laden.
                      onChanged: () => setState(_load),
                    ),
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

// ── Community: Channel-Liste gruppiert nach Kategorie ──────────────
class _ChannelListView extends StatelessWidget {
  const _ChannelListView({required this.future, this.onChanged});
  final Future<List<Map<String, dynamic>>>? future;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // F7: Bronze-Shimmer Conversation-Skeletons (1:1 Tile-Layout).
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: 6,
            itemBuilder: (_, __) => const ConversationTileSkeleton(),
          );
        }
        final list = snap.data ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 100),
              Center(
                child: Column(
                  children: [
                    const Icon(LucideIcons.hash,
                        size: 36, color: AppColors.mute),
                    const SizedBox(height: 10),
                    Text('chat.noChannels'.tr(),
                        style: AppTypography.body(
                            size: 14, color: AppColors.mute)),
                  ],
                ),
              ),
            ],
          );
        }
        // Gruppieren nach category
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final ch in list) {
          final cat = (ch['category'] as String?)?.trim();
          final key = (cat == null || cat.isEmpty) ? 'messages.categoryGeneral'.tr() : cat;
          grouped.putIfAbsent(key, () => []).add(ch);
        }
        final keys = grouped.keys.toList()..sort();
        // Flach gemachte Item-Liste damit ListView.builder lazy rendert.
        final flat = <Object>[];
        for (final cat in keys) {
          flat.add(cat); // Header-Marker
          flat.addAll(grouped[cat]!);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: flat.length,
          itemBuilder: (_, i) {
            final item = flat[i];
            if (item is String) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                child: Text(
                  item.toUpperCase(),
                  style: AppTypography.label(size: 9, color: AppColors.mute),
                ),
              );
            }
            return AnimatedEntrance(
              index: i,
              child: _ChannelTile(
                channel: item as Map<String, dynamic>,
                onChanged: onChanged,
              ),
            );
          },
        );
      },
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  const _ChannelTile({required this.channel, this.onChanged});
  final Map<String, dynamic> channel;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convId = channel['conversation_id'] as String?;
    final name = (channel['name'] as String?) ?? 'messages.channelFallback'.tr();
    final emoji = (channel['emoji'] as String?) ?? '💬';
    final desc = channel['description'] as String?;
    final locked = channel['is_locked'] == true;
    final me = SupabaseService.currentUser?.id;
    // Eigene Räume (Ersteller) dürfen gelöscht werden — Server-RPC prüft die
    // Berechtigung zusätzlich (Ersteller ODER Admin).
    final canDelete = me != null && channel['created_by'] == me;
    final phase = ref.watch(effectiveCinemaPhaseProvider);
    final accent = CinemaAccents.hue(phase);
    return InkWell(
      onTap: convId == null
          ? null
          : () => context.push('/dashboard/messages/$convId'),
      onLongPress: (canDelete && convId != null)
          ? () => _confirmDelete(context, convId, name)
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withValues(alpha: 0.55),
              AppColors.surface.withValues(alpha: 0.30),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: accent.withValues(alpha: 0.22), width: 1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [
                  accent.withValues(alpha: 0.30),
                  accent.withValues(alpha: 0.10),
                ]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: accent.withValues(alpha: 0.45), width: 1),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                              size: 14,
                              color: AppColors.ink,
                              weight: FontWeight.w700),
                        ),
                      ),
                      if (locked)
                        Icon(LucideIcons.lock,
                            size: 12,
                            color: accent.withValues(alpha: 0.7)),
                    ],
                  ),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 14, color: accent.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String convId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('messages.deleteChannelTitle'.tr()),
        content: Text('messages.deleteChannelBody'.tr(namedArgs: {'name': name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr(),
                style: const TextStyle(color: AppColors.herzrot)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final success = await ConversationsRepository.deleteChannel(convId);
    if (!context.mounted) return;
    if (success) {
      Haptics.success();
      AppSnackBar.success(context, 'messages.deleteChannelDone'.tr());
      onChanged?.call();
    } else {
      Haptics.error();
      AppSnackBar.error(context, 'messages.deleteChannelFailed'.tr());
    }
  }
}

// ── Nachrichten: Direct-Message-Liste + Suche ─────────────────────
class _DmListView extends StatelessWidget {
  const _DmListView({
    required this.future,
    required this.search,
    required this.onSearchChanged,
    required this.onlineUserIds,
    required this.onChanged,
  });

  final Future<List<Map<String, dynamic>>>? future;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final Set<String> onlineUserIds;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // F7: Bronze-Shimmer Conversation-Skeletons (1:1 Tile-Layout).
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: 6,
            itemBuilder: (_, __) => const ConversationTileSkeleton(),
          );
        }
        // Fehler sichtbar machen statt still „keine Konversationen" zu zeigen
        // (sonst nicht von echtem Leerzustand unterscheidbar). Scrollbar für
        // Pull-to-Refresh-Konsistenz.
        if (snap.hasError) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 80),
              ErrorStateCard(onRetry: onChanged),
            ],
          );
        }
        final all = snap.data ?? const <Map<String, dynamic>>[];
        // Nur DMs + Groups (channels raus)
        final dms = all.where((c) {
          if (c['is_channel'] == true) return false;
          return c['is_dm'] == true || c['is_group'] == true;
        }).toList();
        if (dms.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 100),
              Center(
                child: Column(
                  children: [
                    const Text('💌', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    Text('chat.noConversations'.tr(),
                        style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        'chat.noConversationsHint'.tr(),
                        style: AppTypography.body(
                            size: 12, color: AppColors.mute),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          );
        }
        final filtered = search.trim().isEmpty
            ? dms
            : dms.where((c) {
                final t = (c['display_title'] as String? ?? '').toLowerCase();
                final s = (c['display_subtitle'] as String? ?? '')
                    .toLowerCase();
                final q = search.toLowerCase();
                return t.contains(q) || s.contains(q);
              }).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
          children: [
            // Suche + Anrufverlauf-Button in einer Zeile.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: onSearchChanged,
                    style: AppTypography.body(size: 13, color: AppColors.ink),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.elevated,
                      prefixIcon: const Icon(LucideIcons.search,
                          size: 14, color: AppColors.mute),
                      hintText: 'chat.searchConversations'.tr(),
                      hintStyle:
                          AppTypography.body(size: 12, color: AppColors.mute),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'callHistory.openHistory'.tr(),
                  icon: const Icon(LucideIcons.history,
                      size: 18, color: AppColors.bronze),
                  onPressed: () => context.push('/dashboard/call-history'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final c in filtered)
              _DmTile(
                conv: c,
                onlineUserIds: onlineUserIds,
                onChanged: onChanged,
              ),
          ],
        );
      },
    );
  }
}

class _DmTile extends ConsumerWidget {
  const _DmTile({
    required this.conv,
    required this.onlineUserIds,
    required this.onChanged,
  });
  final VoidCallback onChanged;
  final Map<String, dynamic> conv;
  final Set<String> onlineUserIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = conv['id'] as String;
    final title = (conv['display_title'] as String?) ??
        (conv['title'] as String?) ??
        'messages.conversationFallback'.tr();
    final subtitle = conv['display_subtitle'] as String?;
    final avatarUrl = conv['peer_avatar_url'] as String?;
    final isDm = conv['is_dm'] == true;
    final updatedAt = DateTime.tryParse(
            (conv['updated_at'] ?? conv['created_at']) as String? ?? '')?.toUtc() ??
        DateTime.now();
    final peerId = conv['peer_user_id'] as String?;
    final online = peerId != null && onlineUserIds.contains(peerId);
    final phase = ref.watch(effectiveCinemaPhaseProvider);
    final accent = CinemaAccents.hue(phase);

    return InkWell(
      onTap: () => context.push('/dashboard/messages/$id'),
      // F1c: Long-Press → Action-Sheet mit Verstecken + Endgueltig loeschen
      onLongPress: isDm
          ? () => _showDmActions(context, ref, id, title,
              onRemoved: onChanged)
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface.withValues(alpha: 0.55),
              AppColors.surface.withValues(alpha: 0.30),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: (online ? AppColors.leben : accent)
                  .withValues(alpha: 0.22),
              width: 1),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // R1: 44 → 52px Avatar fuer mehr visuelles Gewicht.
            Stack(
              children: [
                if (avatarUrl != null)
                  SizedAvatarImage(
                    url: avatarUrl,
                    size: 52,
                    fallbackInitial: title.isNotEmpty ? title[0] : null,
                  )
                else
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.elevated,
                    child: Text(
                      title.isNotEmpty ? title[0].toUpperCase() : '?',
                      style: AppTypography.display(
                          size: 20, color: AppColors.bronze),
                    ),
                  ),
                if (online && isDm)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.leben,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.surface, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.leben.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                              size: 14,
                              color: AppColors.ink,
                              weight: FontWeight.w600),
                        ),
                      ),
                      if (ref
                          .watch(mutedConversationIdsProvider)
                          .maybeWhen(
                              data: (s) => s.contains(id), orElse: () => false))
                        const Padding(
                          padding: EdgeInsets.only(left: 4, right: 4),
                          child: Icon(LucideIcons.bellOff,
                              size: 12, color: AppColors.mute),
                        ),
                      Text(
                        DateFormat('dd.MM. HH:mm').format(updatedAt),
                        style: AppTypography.caption(),
                      ),
                    ],
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft),
                    ),
                  ],
                  if (online && isDm) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.leben,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('common.online'.tr(),
                            style: AppTypography.label(
                                size: 9, color: AppColors.lebenSoft)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // F8: Unread-Badge pro Conv
            Builder(builder: (ctx) {
              final unread = ref
                      .watch(perConversationUnreadProvider)
                      .maybeWhen(
                        data: (m) => m[id] ?? 0,
                        orElse: () => 0,
                      );
              if (unread <= 0) {
                return const Icon(LucideIcons.chevronRight,
                    size: 14, color: AppColors.mute);
              }
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bronze,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bronze.withValues(alpha: 0.55),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: AppTypography.body(
                    size: 11,
                    color: AppColors.voidColor,
                    weight: FontWeight.w700,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── F1c: DM-Aktionen Sheet (Verstecken / Endgueltig loeschen) ──────
/// `onRemoved` wird nach erfolgreicher Loeschung gerufen damit der
/// aufrufende Screen seine eigene Future neu laden kann. Vorher wurde
/// nur ref.invalidate(conversationsProvider) gerufen — das hilft nicht
/// weil messages_screen.dart eine eigene _convs-Future nutzt, keinen
/// Provider — Conv verschwand zwar in DB aber blieb in UI sichtbar.
void _showDmActions(
    BuildContext context, WidgetRef ref, String convId, String title,
    {required VoidCallback onRemoved}) {
  Haptics.longPress();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.sheetBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              title,
              style: AppTypography.body(
                  size: 14, color: AppColors.inkSoft, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(LucideIcons.fileText, color: AppColors.bronze),
            title: Text('chat.recapMenuTitle'.tr(),
                style: AppTypography.body(size: 14, color: AppColors.ink)),
            subtitle: Text('chat.recapMenuHint'.tr(),
                style: AppTypography.caption()),
            onTap: () async {
              Navigator.pop(sheetCtx);
              if (!context.mounted) return;
              await ChatRecapSheet.show(
                context,
                conversationId: convId,
                conversationTitle: title,
              );
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.eyeOff, color: AppColors.mute),
            title: Text('messages.hideForMe'.tr(),
                style: AppTypography.body(size: 14, color: AppColors.ink)),
            subtitle: Text('messages.hideForMeHint'.tr(),
                style: AppTypography.caption()),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final ok =
                  await ConversationsRepository.hideDmForMe(convId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: AppColors.surface,
                content: Text(ok
                    ? 'messages.hidden'.tr()
                    : 'messages.hideFailed'.tr()),
              ));
              if (ok) {
                ref.invalidate(conversationsProvider);
                onRemoved();
              }
            },
          ),
          ListTile(
            leading:
                const Icon(LucideIcons.trash2, color: AppColors.herzrot),
            title: Text('messages.deleteForBoth'.tr(),
                style: AppTypography.body(
                    size: 14, color: AppColors.herzrot)),
            subtitle: Text('messages.deleteForBothHint'.tr(),
                style: AppTypography.caption()),
            onTap: () async {
              Navigator.pop(sheetCtx);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dCtx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: Text('messages.deleteForBothConfirmTitle'.tr(),
                      style: AppTypography.body(
                          size: 15,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                  content: Text('messages.deleteForBothConfirmBody'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.inkSoft,
                          height: 1.4)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx, false),
                      child: Text('common.cancel'.tr()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx, true),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.herzrot),
                      child: Text('messages.deleteForBothAction'.tr()),
                    ),
                  ],
                ),
              );
              if (confirm != true || !context.mounted) return;
              final ok = await ConversationsRepository.deleteDmForBoth(
                  convId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: AppColors.surface,
                content: Text(ok
                    ? 'messages.deletedForBoth'.tr()
                    : 'messages.deleteFailed'.tr()),
              ));
              if (ok) {
                ref.invalidate(conversationsProvider);
                onRemoved();
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ── F2c: User-Picker fuer "Neue DM" ──────────────────────────────────
class _NewDmPickerSheet extends StatefulWidget {
  const _NewDmPickerSheet({required this.scrollCtrl});
  final ScrollController scrollCtrl;

  @override
  State<_NewDmPickerSheet> createState() => _NewDmPickerSheetState();
}

class _NewDmPickerSheetState extends State<_NewDmPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';
  Future<List<Map<String, dynamic>>>? _future;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _future = _fetch(_q);
  }

  Future<List<Map<String, dynamic>>> _fetch(String q) =>
      ProfilesRepository.searchForNewChat(q);

  Future<void> _startChat(String otherId, String name) async {
    if (_creating) return;
    setState(() => _creating = true);
    String? convId;
    try {
      convId = await ConversationsRepository.getOrCreateDm(otherId);
    } catch (_) {
      convId = null;
    } finally {
      // Guard immer zurücksetzen wenn der Screen noch lebt — sonst bleibt
      // der Button bei Fehler dauerhaft disabled (Spur-1-Bug).
      if (mounted) setState(() => _creating = false);
    }
    if (!mounted) return;
    if (convId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('messages.newDmFailed'.tr(),
            style: AppTypography.body(
                size: 13, color: AppColors.herzrotWarm)),
      ));
      return;
    }
    if (!mounted) return;
    // BUG-FIX: Navigator.pop schliesst das Sheet → der lokale `context`
    // ist danach TOT. context.push() danach passiert auf disposed
    // context → kein Effekt. Loesung: NavigatorState ueber den
    // rootNavigatorKey holen und dort pushen, NACHDEM das Sheet zu ist.
    Navigator.pop(context);
    // Nach Sheet-Close auf root-navigator pushen (lebt unabhaengig).
    rootNavigatorKey.currentState?.context.push('/dashboard/messages/$convId');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(LucideIcons.messageSquarePlus,
                  color: AppColors.bronze),
              const SizedBox(width: 10),
              Expanded(
                child: Text('messages.newDmTitle'.tr(),
                    style: AppTypography.body(
                        size: 16,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: (v) => setState(() {
              _q = v;
              _load();
            }),
            style: AppTypography.body(size: 14, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'messages.searchUser'.tr(),
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
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                );
              }
              final users = snap.data ?? const <Map<String, dynamic>>[];
              if (users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _q.isEmpty
                          ? 'messages.noUsersFound'.tr()
                          : 'messages.noUsersForQuery'.tr(),
                      style: AppTypography.body(
                          size: 13, color: AppColors.mute),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: widget.scrollCtrl,
                itemCount: users.length,
                itemBuilder: (_, i) {
                  final u = users[i];
                  final name = (u['display_name'] as String?) ??
                      (u['name'] as String?) ??
                      (u['nickname'] as String?) ??
                      'Nachbar:in';
                  final avatar = u['avatar_url'] as String?;
                  final loc = u['location'] as String?;
                  return ListTile(
                    leading: SizedAvatarImage(
                      url: avatar,
                      size: 40,
                      fallbackInitial: name,
                    ),
                    title: Text(name,
                        style: AppTypography.body(
                            size: 14, color: AppColors.ink)),
                    subtitle: loc != null && loc.isNotEmpty
                        ? Text(loc, style: AppTypography.caption())
                        : null,
                    trailing: _creating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.bronze),
                          )
                        : const Icon(LucideIcons.chevronRight,
                            size: 16, color: AppColors.mute),
                    onTap: () => _startChat(u['id'] as String, name),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
