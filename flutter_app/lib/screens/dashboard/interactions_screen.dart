import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/interaction.dart';
import '../../repositories/interactions_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Interactions-Screen: alle aktiven Hilfeanfragen des Users.
class InteractionsScreen extends ConsumerStatefulWidget {
  const InteractionsScreen({super.key});

  @override
  ConsumerState<InteractionsScreen> createState() => _InteractionsScreenState();
}

class _InteractionsScreenState extends ConsumerState<InteractionsScreen> {
  Future<List<Interaction>>? _future;

  @override
  void initState() {
    super.initState();
    _future = InteractionsRepository.getActive();
  }

  Future<void> _refresh() async {
    final fresh = InteractionsRepository.getActive();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Interaktionen',
      currentRoute: '/dashboard/interactions',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<Interaction>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                );
              }
              final all = snap.data ?? const <Interaction>[];
              if (all.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.helpingHand,
                            size: 32,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keine aktiven Interaktionen.',
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
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final it = all[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.4),
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusBadge(status: it.status),
                            const Spacer(),
                            Text(
                              DateFormat('dd.MM.yyyy HH:mm')
                                  .format(it.updatedAt),
                              style: AppTypography.caption(),
                            ),
                          ],
                        ),
                        if (it.message != null && it.message!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            it.message!,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.inkSoft,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cfg = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.color.withValues(alpha: 0.18),
        border: Border.all(color: cfg.color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        cfg.label,
        style: AppTypography.label(size: 9, color: cfg.color),
      ),
    );
  }

  static ({String label, Color color}) _config(String s) {
    switch (s) {
      case 'pending':
        return (label: 'Wartet', color: AppColors.amber);
      case 'accepted':
        return (label: 'Angenommen', color: AppColors.leben);
      case 'on_way':
        return (label: 'Unterwegs', color: AppColors.teal);
      case 'arrived':
        return (label: 'Vor Ort', color: AppColors.tealSoft);
      case 'completed':
        return (label: 'Abgeschlossen', color: AppColors.leben);
      case 'cancelled':
        return (label: 'Abgebrochen', color: AppColors.mute);
      default:
        return (label: s, color: AppColors.mute);
    }
  }
}
