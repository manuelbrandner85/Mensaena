import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../config/theme/cinema_accents.dart';
import '../../providers/cinema_provider.dart';
import '../../repositories/conversations_repository.dart';
import '../../services/presence_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/skeleton_card.dart';

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

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'messages.title'.tr(),
      currentRoute: '/dashboard/messages',
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
                    child: _ChannelListView(future: _channels),
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
  const _ChannelListView({required this.future});
  final Future<List<Map<String, dynamic>>>? future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // BUG-FIX #14: Skeleton-Loader statt Spinner
          return const SkeletonList(count: 5, itemHeight: 76);
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            for (final cat in keys) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                child: Text(
                  cat.toUpperCase(),
                  style: AppTypography.label(size: 9, color: AppColors.mute),
                ),
              ),
              for (final ch in grouped[cat]!) _ChannelTile(channel: ch),
            ],
          ],
        );
      },
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  const _ChannelTile({required this.channel});
  final Map<String, dynamic> channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convId = channel['conversation_id'] as String?;
    final name = (channel['name'] as String?) ?? 'messages.channelFallback'.tr();
    final emoji = (channel['emoji'] as String?) ?? '💬';
    final desc = channel['description'] as String?;
    final locked = channel['is_locked'] == true;
    final phase = ref.watch(effectiveCinemaPhaseProvider);
    final accent = CinemaAccents.hue(phase);
    return InkWell(
      onTap: convId == null
          ? null
          : () => context.go('/dashboard/messages/$convId'),
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
}

// ── Nachrichten: Direct-Message-Liste + Suche ─────────────────────
class _DmListView extends StatelessWidget {
  const _DmListView({
    required this.future,
    required this.search,
    required this.onSearchChanged,
    required this.onlineUserIds,
  });

  final Future<List<Map<String, dynamic>>>? future;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final Set<String> onlineUserIds;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // BUG-FIX #14: Skeleton-Loader statt Spinner
          return const SkeletonList(count: 5, itemHeight: 76);
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
            // Suche-Input
            TextField(
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final c in filtered)
              _DmTile(conv: c, onlineUserIds: onlineUserIds),
          ],
        );
      },
    );
  }
}

class _DmTile extends ConsumerWidget {
  const _DmTile({required this.conv, required this.onlineUserIds});
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
            (conv['updated_at'] ?? conv['created_at']) as String? ?? '') ??
        DateTime.now();
    final peerId = conv['peer_user_id'] as String?;
    final online = peerId != null && onlineUserIds.contains(peerId);
    final phase = ref.watch(effectiveCinemaPhaseProvider);
    final accent = CinemaAccents.hue(phase);

    return InkWell(
      onTap: () => context.go('/dashboard/messages/$id'),
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
            Stack(
              children: [
                CircleAvatar(
                  radius: 22, // 44dp — empfohlene Touch-Affordanz
                  backgroundColor: AppColors.elevated,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? const Icon(LucideIcons.user,
                          size: 20, color: AppColors.bronze)
                      : null,
                ),
                if (online && isDm)
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
            const Icon(LucideIcons.chevronRight,
                size: 14, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}
