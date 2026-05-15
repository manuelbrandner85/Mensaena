import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_avatar.dart';
import '../../core/widgets/cinema_bottom_nav.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_tabs.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase/database_service.dart';

final conversationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return db.listConversations(user.id);
});

final allChannelsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return db.listChannels();
});

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late final TabController _tabs;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conv = ref.watch(conversationsProvider);
    final channels = ref.watch(allChannelsProvider);
    final isAdmin = ref.watch(_isAdminProvider).asData?.value ?? false;

    return CinemaScaffold(
      appBar: CinemaAppBar(
        title: 'CHAT',
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(
                LucideIcons.settings,
                size: 20,
                color: MnColors.amber,
              ),
              tooltip: 'Channels verwalten',
              onPressed: () => GoRouter.of(context).push('/chat/channels'),
            ),
        ],
      ),
      bottomNavigationBar: CinemaBottomNav(
        currentIndex: 3,
        onTap: (i) {
          switch (i) {
            case 0:
              GoRouter.of(context).go('/dashboard');
              break;
            case 1:
              GoRouter.of(context).go('/map');
              break;
            case 2:
              GoRouter.of(context).push('/posts/new');
              break;
            case 3:
              break;
            case 4:
              GoRouter.of(context).go('/profile/me');
              break;
          }
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            CinemaTabs(
              controller: _tabs,
              labels: const ['Direkt', 'Kanaele'],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: CinemaInput(
                controller: _search,
                placeholder: 'Durchsuchen',
                variant: CinemaInputVariant.search,
                onChanged: (v) => setState(() => _q = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tabs.index,
                children: [
                  _DirectList(query: _q, conv: conv),
                  _ChannelsList(query: _q, channels: channels),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;
  return db.isAdmin(user.id);
});

class _DirectList extends StatelessWidget {
  final String query;
  final AsyncValue<List<Map<String, dynamic>>> conv;
  const _DirectList({required this.query, required this.conv});

  @override
  Widget build(BuildContext context) {
    return conv.when(
      loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
      error: (e, _) => CinemaEmptyState(
        icon: LucideIcons.alertCircle,
        title: 'Fehler beim Laden',
        message: e.toString(),
      ),
      data: (list) {
        final direct = list.where((c) {
          final inner = (c['conversations'] as Map<String, dynamic>?) ?? const {};
          final type = inner['type'] as String?;
          return type == null || type == 'direct' || type == 'group';
        }).toList();
        if (direct.isEmpty) {
          return const CinemaEmptyState(
            icon: LucideIcons.messageCircle,
            title: 'Noch keine Gespraeche.',
            message:
                'Schreib einer Nachbarin oder einem Nachbarn die erste Nachricht.',
          );
        }
        final filtered = query.isEmpty
            ? direct
            : direct.where((c) {
                final inner = (c['conversations'] as Map<String, dynamic>?) ??
                    const {};
                return '${inner['title'] ?? inner['name'] ?? ''}'
                    .toLowerCase()
                    .contains(query);
              }).toList();
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(color: MnColors.line),
          itemBuilder: (_, i) => _ConvTile(conv: filtered[i]),
        );
      },
    );
  }
}

class _ChannelsList extends StatelessWidget {
  final String query;
  final AsyncValue<List<Map<String, dynamic>>> channels;
  const _ChannelsList({required this.query, required this.channels});

  @override
  Widget build(BuildContext context) {
    return channels.when(
      loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
      error: (e, _) => CinemaEmptyState(
        icon: LucideIcons.alertCircle,
        title: 'Fehler beim Laden',
        message: e.toString(),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const CinemaEmptyState(
            icon: LucideIcons.hash,
            title: 'Noch keine Kanaele.',
            message: 'Bitte einen Admin, Kanaele anzulegen.',
          );
        }
        final filtered = query.isEmpty
            ? list
            : list
                .where(
                  (c) =>
                      ((c['name'] as String?) ?? '').toLowerCase().contains(query),
                )
                .toList();
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(color: MnColors.line),
          itemBuilder: (_, i) => _ChannelTile(channel: filtered[i]),
        );
      },
    );
  }
}

class _ConvTile extends StatelessWidget {
  final Map<String, dynamic> conv;
  const _ConvTile({required this.conv});

  @override
  Widget build(BuildContext context) {
    final inner =
        (conv['conversations'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final convId =
        inner['id'] as String? ?? conv['conversation_id'] as String?;
    final title = (inner['title'] as String?) ??
        (inner['name'] as String?) ??
        'Konversation';
    return InkWell(
      onTap: convId == null
          ? null
          : () => GoRouter.of(context).push('/chat/$convId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const CinemaAvatar(size: AvatarSize.md),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: MnTypography.body(weight: FontWeight.w600),
                  ),
                  Text(
                    (inner['last_message'] as String?) ?? '',
                    style: MnTypography.body(color: MnColors.mute, size: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _ChannelTile extends StatelessWidget {
  final Map<String, dynamic> channel;
  const _ChannelTile({required this.channel});

  @override
  Widget build(BuildContext context) {
    final convId = channel['conversation_id'] as String?;
    final name = (channel['name'] as String?) ?? 'Kanal';
    final desc = (channel['description'] as String?) ?? '';
    final emoji = (channel['emoji'] as String?) ?? '#';
    return InkWell(
      onTap: convId == null
          ? null
          : () => GoRouter.of(context).push('/chat/$convId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MnColors.elevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: MnColors.line),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: MnTypography.body(weight: FontWeight.w600),
                  ),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      style: MnTypography.body(color: MnColors.mute, size: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
