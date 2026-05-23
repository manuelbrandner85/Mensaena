import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/conversations_repository.dart';
import '../../services/presence_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Konversations-Liste sortiert nach updated_at.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ConversationsRepository.listMine();
  }

  Future<void> _refresh() async {
    final fresh = ConversationsRepository.listMine();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Nachrichten',
      currentRoute: '/dashboard/messages',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                );
              }
              final convs = snap.data ?? const [];
              if (convs.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.messagesSquare,
                            size: 32,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Noch keine Konversationen.',
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: convs.length,
                itemBuilder: (context, i) {
                  final c = convs[i];
                  final id = c['id'] as String;
                  // Verwende display_title aus enriched listMine
                  // (Channel-Name mit Emoji ODER Partner-Display-Name).
                  final title = (c['display_title'] as String?) ??
                      (c['title'] as String?) ??
                      'Konversation';
                  final subtitle = c['display_subtitle'] as String?;
                  final avatarUrl = c['peer_avatar_url'] as String?;
                  final isChannel = c['is_channel'] == true;
                  final isDm = c['is_dm'] == true;
                  final updatedAt = DateTime.tryParse(
                          (c['updated_at'] ?? c['created_at']) as String? ??
                              '') ??
                      DateTime.now();
                  final peerId = c['peer_user_id'] as String?;
                  final online = peerId != null &&
                      (ref.watch(onlineUsersProvider).value ??
                              const <String>{})
                          .contains(peerId);
                  return InkWell(
                    onTap: () => context.go('/dashboard/messages/$id'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.4),
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.elevated,
                                backgroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? isChannel
                                        ? Text(
                                            (c['channel'] as Map?)?[
                                                    'emoji']
                                                    as String? ??
                                                '💬',
                                            style: const TextStyle(
                                                fontSize: 18),
                                          )
                                        : const Icon(
                                            LucideIcons.user,
                                            size: 16,
                                            color: AppColors.amber,
                                          )
                                    : null,
                              ),
                              if (online && isDm)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppColors.leben,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.surface,
                                          width: 2),
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
                                Text(
                                  title,
                                  style: AppTypography.body(
                                    size: 14,
                                    color: AppColors.ink,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (online) ...[
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.leben,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text('Online',
                                          style: AppTypography.label(
                                              size: 9,
                                              color: AppColors.lebenSoft)),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      DateFormat('dd.MM.yyyy HH:mm')
                                          .format(updatedAt),
                                      style: AppTypography.caption(),
                                    ),
                                  ],
                                ),
                                if (subtitle != null &&
                                    subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: AppColors.mute,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
