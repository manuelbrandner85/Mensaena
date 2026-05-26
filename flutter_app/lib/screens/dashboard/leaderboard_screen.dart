/// SKILL: mensaena-features (F46)
/// Leaderboard — Top 10 nach karma_points. Podest-Visual fuer Top-3.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/mega_providers.dart';
import '../../widgets/effects/bloom.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider);
    return DashboardScaffold(
      title: 'community.leaderboard'.tr(),
      currentRoute: '/dashboard/leaderboard',
      onRefresh: () async {
        ref.invalidate(leaderboardProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Text('community.no_leaderboard'.tr(),
                  style: AppTypography.caption()),
            );
          }
          final top3 = rows.take(3).toList();
          final rest = rows.skip(3).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text('community.this_week'.tr(),
                  style: AppTypography.label(
                      size: 10, color: AppColors.bronze)),
              const SizedBox(height: 16),
              if (top3.isNotEmpty) _Podium(top3: top3),
              const SizedBox(height: 24),
              for (int i = 0; i < rest.length; i++)
                _RankRow(rank: i + 4, row: rest[i]),
            ],
          );
        },
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top3});
  final List<Map<String, dynamic>> top3;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (top3.length > 1)
          Expanded(child: _PodiumStep(rank: 2, row: top3[1], height: 110)),
        Expanded(
            child: _PodiumStep(rank: 1, row: top3[0], height: 150)),
        if (top3.length > 2)
          Expanded(child: _PodiumStep(rank: 3, row: top3[2], height: 90)),
      ],
    );
  }
}

class _PodiumStep extends StatelessWidget {
  const _PodiumStep({
    required this.rank,
    required this.row,
    required this.height,
  });
  final int rank;
  final Map<String, dynamic> row;
  final double height;

  Color get _color {
    switch (rank) {
      case 1:
        return AppColors.amber;
      case 2:
        return AppColors.tealSoft;
      case 3:
        return AppColors.bronze;
      default:
        return AppColors.mute;
    }
  }

  String get _medal {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = row['avatar_url'] as String?;
    final name = (row['display_name'] ?? row['name']) as String?;
    final karma = (row['karma_points'] as num?)?.toInt() ?? 0;
    final displayName = name == null || name.isEmpty
        ? '?'
        : (name.length > 1 ? '${name[0]}. ${name.split(' ').last}' : name);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_medal, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Bloom(
          color: _color,
          intensity: 0.5,
          radius: 12,
          child: CircleAvatar(
            radius: rank == 1 ? 32 : 26,
            backgroundColor: AppColors.surface,
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? CachedNetworkImageProvider(avatar)
                : null,
            child: (avatar == null || avatar.isEmpty)
                ? Text((name ?? '?').substring(0, 1).toUpperCase(),
                    style: AppTypography.display(
                        size: 18, color: _color))
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
                size: 11,
                color: AppColors.ink,
                weight: FontWeight.w700)),
        Text('$karma',
            style: AppTypography.mono(
                size: 12, color: _color, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.15),
            border: Border(top: BorderSide(color: _color, width: 2)),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: Text('$rank',
              style: AppTypography.display(size: 20, color: _color)),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.row});
  final int rank;
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final avatar = row['avatar_url'] as String?;
    final name =
        (row['display_name'] ?? row['name']) as String? ?? '?';
    final karma = (row['karma_points'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$rank',
                style: AppTypography.mono(
                    size: 13,
                    color: AppColors.mute,
                    weight: FontWeight.w700)),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surface,
            backgroundImage: avatar != null && avatar.isNotEmpty
                ? CachedNetworkImageProvider(avatar)
                : null,
            child: (avatar == null || avatar.isEmpty)
                ? Text(name.substring(0, 1).toUpperCase(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.bronze))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                    size: 13,
                    color: AppColors.ink,
                    weight: FontWeight.w600)),
          ),
          Row(
            children: [
              const Icon(LucideIcons.trophy,
                  size: 12, color: AppColors.mute),
              const SizedBox(width: 4),
              Text('$karma',
                  style: AppTypography.mono(
                      size: 12,
                      color: AppColors.bronze,
                      weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}
