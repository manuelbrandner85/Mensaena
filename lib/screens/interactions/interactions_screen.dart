import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/interaction_provider.dart';
import 'package:mensaena/models/interaction.dart';
import 'package:mensaena/widgets/badge_widget.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class InteractionsScreen extends ConsumerStatefulWidget {
  const InteractionsScreen({super.key});
  @override
  ConsumerState<InteractionsScreen> createState() => _InteractionsScreenState();
}

class _InteractionsScreenState extends ConsumerState<InteractionsScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      _channel = Supabase.instance.client.channel('interactions-$userId')
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'interactions',
            callback: (_) { if (mounted) ref.invalidate(interactionsProvider); })
          .subscribe();
    }
  }

  @override
  void dispose() { _channel?.unsubscribe(); super.dispose(); }

  @override
  @override
  Widget build(BuildContext context) {
    final interactionsAsync = ref.watch(interactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('§ 06 · Interaktionen'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(interactionsProvider),
        color: AppColors.primary500,
        child: interactionsAsync.when(
          loading: () => const LoadingSkeleton(type: SkeletonType.card),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (interactions) {
            if (interactions.isEmpty) {
              return const EmptyState(
                icon: Icons.handshake_outlined,
                title: 'Keine Interaktionen',
                message: 'Hier siehst du deine Hilfsangebote und -anfragen.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: interactions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InteractionCard(
                    interaction: interactions[index],
                    onTap: () => context.push('/dashboard/interactions/${interactions[index].id}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _InteractionCard extends StatelessWidget {
  final Interaction interaction;
  final VoidCallback onTap;
  const _InteractionCard({required this.interaction, required this.onTap});

  Color _getStatusColor(InteractionStatus status) {
    switch (status) {
      case InteractionStatus.requested:
        return AppColors.info;
      case InteractionStatus.accepted:
        return AppColors.success;
      case InteractionStatus.inProgress:
        return AppColors.primary500;
      case InteractionStatus.completed:
        return AppColors.success;
      case InteractionStatus.disputed:
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getStatusIcon(InteractionStatus status) {
    switch (status) {
      case InteractionStatus.requested:
        return Icons.schedule;
      case InteractionStatus.accepted:
        return Icons.check_circle_outline;
      case InteractionStatus.inProgress:
        return Icons.play_circle_outline;
      case InteractionStatus.completed:
        return Icons.task_alt;
      case InteractionStatus.disputed:
        return Icons.warning_amber;
      default:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = interaction.interactionStatus;
    final statusColor = _getStatusColor(status);
    final postTitle = interaction.post?['title'] as String? ?? 'Beitrag';
    final helperName = interaction.helperProfile?['nickname'] as String? ?? 'Unbekannt';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getStatusIcon(status), color: statusColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    postTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      AvatarWidget(
                        imageUrl: interaction.helperProfile?['avatar_url'] as String?,
                        name: helperName,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(helperName, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(interaction.createdAt, locale: 'de'),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppBadge(label: status.label, color: statusColor, small: true),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
