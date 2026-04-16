import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/interaction_provider.dart';
import 'package:mensaena/models/interaction.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/badge_widget.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class InteractionDetailScreen extends ConsumerWidget {
  final String interactionId;
  const InteractionDetailScreen({super.key, required this.interactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interactionAsync = ref.watch(interactionDetailProvider(interactionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Interaktion')),
      body: interactionAsync.when(
        loading: () => const LoadingSkeleton(type: SkeletonType.card),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (interaction) {
          if (interaction == null) return const Center(child: Text('Interaktion nicht gefunden'));

          final status = interaction.interactionStatus;
          final statusColor = _getStatusColor(status);
          final postTitle = interaction.post?['title'] as String? ?? 'Beitrag';
          final postDesc = interaction.post?['description'] as String?;
          final helperName = interaction.helperProfile?['nickname'] as String? ?? 'Unbekannt';
          final ownerName = interaction.postOwnerProfile?['nickname'] as String? ?? 'Unbekannt';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(_getStatusIcon(status), color: statusColor, size: 36),
                      const SizedBox(height: 8),
                      AppBadge(label: status.label, color: statusColor),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(interaction.createdAt, locale: 'de'),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Post info
                const Text('Beitrag', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context.push('/dashboard/posts/${interaction.postId}'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(postTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        if (postDesc != null) ...[
                          const SizedBox(height: 4),
                          Text(postDesc, style: const TextStyle(fontSize: 13, color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // People
                const Text('Beteiligte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                // Helper
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: AvatarWidget(
                    imageUrl: interaction.helperProfile?['avatar_url'] as String?,
                    name: helperName,
                    size: 40,
                  ),
                  title: Text(helperName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Helfer'),
                  onTap: () => context.push('/dashboard/profile/${interaction.helperId}'),
                ),

                // Owner
                if (interaction.postOwnerProfile != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarWidget(
                      imageUrl: interaction.postOwnerProfile!['avatar_url'] as String?,
                      name: ownerName,
                      size: 40,
                    ),
                    title: Text(ownerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Beitragsersteller'),
                  ),

                // Message
                if (interaction.message != null) ...[
                  const SizedBox(height: 16),
                  const Text('Nachricht', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(interaction.message!, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ),
                ],

                // Timeline
                const SizedBox(height: 20),
                const Text('Zeitverlauf', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),

                _TimelineItem(
                  title: 'Angefragt',
                  time: timeago.format(interaction.createdAt, locale: 'de'),
                  isActive: true,
                ),
                if (status != InteractionStatus.requested)
                  _TimelineItem(
                    title: status == InteractionStatus.accepted ? 'Angenommen' : status.label,
                    time: interaction.updatedAt != null ? timeago.format(interaction.updatedAt!, locale: 'de') : '',
                    isActive: true,
                  ),
                if (interaction.completedAt != null)
                  _TimelineItem(
                    title: 'Abgeschlossen',
                    time: timeago.format(interaction.completedAt!, locale: 'de'),
                    isActive: true,
                    isLast: true,
                  ),

                const SizedBox(height: 24),

                // Actions
                if (status == InteractionStatus.requested)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await ref.read(interactionServiceProvider).updateStatus(interactionId, 'cancelled_by_helper');
                            ref.invalidate(interactionDetailProvider(interactionId));
                            ref.invalidate(interactionsProvider);
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Ablehnen'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await ref.read(interactionServiceProvider).updateStatus(interactionId, 'accepted');
                            ref.invalidate(interactionDetailProvider(interactionId));
                            ref.invalidate(interactionsProvider);
                          },
                          child: const Text('Annehmen'),
                        ),
                      ),
                    ],
                  ),

                if (status == InteractionStatus.accepted || status == InteractionStatus.inProgress)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(interactionServiceProvider).updateStatus(interactionId, 'completed');
                        ref.invalidate(interactionDetailProvider(interactionId));
                        ref.invalidate(interactionsProvider);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Als erledigt markieren'),
                    ),
                  ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

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
      default:
        return Icons.info_outline;
    }
  }
}

class _TimelineItem extends StatelessWidget {
  final String title;
  final String time;
  final bool isActive;
  final bool isLast;
  const _TimelineItem({required this.title, required this.time, this.isActive = false, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? AppColors.primary500 : AppColors.border,
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 30, color: isActive ? AppColors.primary500 : AppColors.border),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
