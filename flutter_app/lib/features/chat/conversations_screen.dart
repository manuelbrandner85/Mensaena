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
import '../../providers/auth_provider.dart';
import '../../services/supabase/database_service.dart';

final conversationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return db.listConversations(user.id);
});

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conv = ref.watch(conversationsProvider);

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'CHAT'),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: CinemaInput(
                controller: _search,
                placeholder: 'Konversationen durchsuchen',
                variant: CinemaInputVariant.search,
                onChanged: (v) => setState(() => _q = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: conv.when(
                loading: () =>
                    const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
                error: (e, _) => CinemaEmptyState(
                  icon: LucideIcons.alertCircle,
                  title: 'Fehler beim Laden',
                  message: e.toString(),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const CinemaEmptyState(
                      icon: LucideIcons.messageCircle,
                      title: 'Noch keine Gespraeche.',
                      message: 'Schreib einer Nachbarin oder einem Nachbarn die erste Nachricht.',
                    );
                  }
                  final filtered = _q.isEmpty
                      ? list
                      : list.where((c) => '${c['name'] ?? ''}'.toLowerCase().contains(_q)).toList();
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(color: MnColors.line),
                    itemBuilder: (_, i) => _ConvTile(conv: filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvTile extends StatelessWidget {
  final Map<String, dynamic> conv;
  const _ConvTile({required this.conv});

  @override
  Widget build(BuildContext context) {
    final inner = (conv['conversations'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final convId = inner['id'] as String? ?? conv['conversation_id'] as String?;
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
                    (inner['name'] as String?) ?? 'Konversation',
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
