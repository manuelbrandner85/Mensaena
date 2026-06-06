/// SKILL: mensaena-features
/// ActivityFeedWidget — letzte Interaktionen (Realtime-Stream).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/interactions_repository.dart';
import 'tile_error.dart';

class ActivityFeedWidget extends ConsumerWidget {
  const ActivityFeedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(interactionsStreamProvider);
    return stream.when(
      loading: () => const SizedBox(height: 80),
      error: (_, __) => DashboardTileError(onRetry: () => ref.invalidate(interactionsStreamProvider)),
      data: (interactions) {
        if (interactions.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.activity,
                      color: AppColors.amber, size: 14),
                  const SizedBox(width: 6),
                  Text('home.activity'.tr(),
                      style: AppTypography.label(
                          size: 10, color: AppColors.amber)),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        context.go('/dashboard/interactions'),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 24),
                    ),
                    child: Text('home.all'.tr(),
                        style: AppTypography.label(
                            size: 9, color: AppColors.amber)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final ix in interactions.take(3))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor(ix.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusLabel(ix.status),
                          style: AppTypography.body(
                              size: 12, color: AppColors.inkSoft),
                        ),
                      ),
                      Text(
                        _relativeTime(ix.createdAt),
                        style: AppTypography.caption(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return AppColors.amber;
      case 'accepted':
        return AppColors.lebenSoft;
      case 'on_way':
        return AppColors.tealSoft;
      case 'arrived':
        return AppColors.leben;
      default:
        return AppColors.mute;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Anfrage gesendet';
      case 'accepted':
        return 'Hilfe zugesagt';
      case 'on_way':
        return 'Unterwegs';
      case 'arrived':
        return 'Angekommen';
      default:
        return s;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'jetzt';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
