import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/interaction_provider.dart';
import 'package:mensaena/providers/trust_provider.dart';
import 'package:mensaena/models/interaction.dart';
import 'package:mensaena/widgets/badge_widget.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';
import 'package:mensaena/widgets/rating_dialog.dart';
import 'package:mensaena/widgets/editorial_header.dart';

class InteractionsScreen extends ConsumerStatefulWidget {
  const InteractionsScreen({super.key});
  @override
  ConsumerState<InteractionsScreen> createState() => _InteractionsScreenState();
}

class _InteractionsScreenState extends ConsumerState<InteractionsScreen> {
  RealtimeChannel? _channel;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      _channel = Supabase.instance.client.channel('interactions-$userId')
          .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'interactions',
            callback: (_) {
              if (mounted) {
                ref.invalidate(interactionsProvider);
                ref.invalidate(interactionStatsProvider);
              }
            })
          .subscribe();
    }
  }

  @override
  void dispose() { _channel?.unsubscribe(); super.dispose(); }

  List<Interaction> _applyFilter(List<Interaction> items) {
    if (_statusFilter == 'all') return items;
    return items.where((i) {
      if (_statusFilter == 'in_progress') {
        return i.status == 'accepted' || i.status == 'in_progress';
      }
      return i.status == _statusFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final interactionsAsync = ref.watch(interactionsProvider);
    final statsAsync = ref.watch(interactionStatsProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('§ 06 · Interaktionen'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(interactionsProvider);
          ref.invalidate(interactionStatsProvider);
        },
        color: AppColors.primary500,
        child: interactionsAsync.when(
          loading: () => const LoadingSkeleton(type: SkeletonType.card),
          error: (e, _) => Center(child: Text('Fehler: $e')),
          data: (interactions) {
            final stats = statsAsync.asData?.value ?? const <String, int>{};
            final newCount = stats['requested'] ?? 0;
            final activeCount = (stats['accepted'] ?? 0) + (stats['in_progress'] ?? 0);
            final rateCount = stats['completed'] ?? 0;
            final filtered = _applyFilter(interactions);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const EditorialHeader(
                  section: 'INTERAKTIONEN',
                  number: '09',
                  title: 'Meine Interaktionen',
                  subtitle: 'Deine Hilfe-Aktivitäten',
                  icon: Icons.handshake_outlined,
                ),
                const SizedBox(height: 16),
                const _StatusFlowBar(),
                const SizedBox(height: 16),
                _BadgeCounterRow(
                  newCount: newCount,
                  activeCount: activeCount,
                  rateCount: rateCount,
                ),
                const SizedBox(height: 16),
                _StatusFilterChips(
                  current: _statusFilter,
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: EmptyState(
                      icon: Icons.handshake_outlined,
                      title: 'Keine Interaktionen',
                      message: 'Hier siehst du deine Hilfsangebote und -anfragen.',
                    ),
                  )
                else
                  ...filtered.map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InteractionCard(
                          interaction: i,
                          currentUserId: userId,
                          onTap: () => context.push('/dashboard/interactions/${i.id}'),
                          onUpdate: () async {
                            ref.invalidate(interactionsProvider);
                            ref.invalidate(interactionStatsProvider);
                          },
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusFlowBar extends StatelessWidget {
  const _StatusFlowBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _FlowStep(label: 'Angefragt', icon: Icons.schedule),
          _FlowArrow(),
          _FlowStep(label: 'Angenommen', icon: Icons.check_circle_outline),
          _FlowArrow(),
          _FlowStep(label: 'Aktiv', icon: Icons.play_circle_outline),
          _FlowArrow(),
          _FlowStep(label: 'Fertig', icon: Icons.task_alt),
          _FlowArrow(),
          _FlowStep(label: 'Bewertet', icon: Icons.star_outline),
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FlowStep({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.primary500),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 18),
      child: Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
    );
  }
}

class _BadgeCounterRow extends StatelessWidget {
  final int newCount;
  final int activeCount;
  final int rateCount;
  const _BadgeCounterRow({
    required this.newCount,
    required this.activeCount,
    required this.rateCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _CountBadge(label: 'Neue', value: newCount, color: AppColors.info, icon: Icons.schedule)),
        const SizedBox(width: 8),
        Expanded(child: _CountBadge(label: 'Aktive', value: activeCount, color: AppColors.primary500, icon: Icons.play_circle_outline)),
        const SizedBox(width: 8),
        Expanded(child: _CountBadge(label: 'Bewertung', value: rateCount, color: AppColors.warning, icon: Icons.star_outline)),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _CountBadge({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _StatusFilterChips({required this.current, required this.onChanged});

  static const _filters = [
    ('all', 'Alle'),
    ('requested', 'Angefragt'),
    ('accepted', 'Angenommen'),
    ('in_progress', 'Aktiv'),
    ('completed', 'Abgeschlossen'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((f) {
          final selected = current == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: selected,
              onSelected: (_) => onChanged(f.$1),
              selectedColor: AppColors.primary500.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary500,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InteractionCard extends ConsumerWidget {
  final Interaction interaction;
  final String? currentUserId;
  final VoidCallback onTap;
  final Future<void> Function() onUpdate;
  const _InteractionCard({
    required this.interaction,
    required this.currentUserId,
    required this.onTap,
    required this.onUpdate,
  });

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

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, String newStatus) async {
    try {
      await ref.read(interactionServiceProvider).updateStatus(interaction.id, newStatus);
      await onUpdate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    final helperName = interaction.helperProfile?['name'] as String? ??
        interaction.helperProfile?['nickname'] as String? ?? 'Helfer';
    await RatingDialog.show(
      context,
      title: 'Bewertung abgeben',
      subtitle: 'Wie war die Zusammenarbeit mit $helperName?',
      onSubmit: (rating, comment) async {
        final userId = ref.read(currentUserIdProvider);
        if (userId == null) return;
        await ref.read(trustServiceProvider).createRating(
          raterId: userId,
          ratedId: interaction.helperId,
          score: rating,
          comment: comment,
          category: 'interaction',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bewertung abgegeben')),
          );
        }
      },
    );
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref) {
    final status = interaction.interactionStatus;
    final postOwnerId = interaction.post?['user_id'] as String?;
    final isHelper = currentUserId != null && currentUserId == interaction.helperId;
    final isOwner = currentUserId != null && currentUserId == postOwnerId;

    switch (status) {
      case InteractionStatus.requested:
        if (isOwner) {
          return [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateStatus(context, ref, 'accepted'),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Annehmen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _updateStatus(context, ref, 'cancelled_by_helped'),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Ablehnen'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ];
        }
        return [];
      case InteractionStatus.accepted:
        return [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(context, ref, 'in_progress'),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Starten'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ];
      case InteractionStatus.inProgress:
        return [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(context, ref, 'completed'),
              icon: const Icon(Icons.task_alt, size: 16),
              label: const Text('Abschließen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ];
      case InteractionStatus.completed:
        if (isOwner && !isHelper) {
          return [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _rate(context, ref),
                icon: const Icon(Icons.star, size: 16),
                label: const Text('Bewerten'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ];
        }
        return [];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = interaction.interactionStatus;
    final statusColor = _getStatusColor(status);
    final postTitle = interaction.post?['title'] as String? ?? 'Beitrag';
    final helperName = interaction.helperProfile?['name'] as String? ??
        interaction.helperProfile?['nickname'] as String? ?? 'Unbekannt';
    final actions = _buildActions(context, ref);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                          Expanded(
                            child: Text(
                              helperName,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
