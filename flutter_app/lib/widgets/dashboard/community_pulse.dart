/// SKILL: mensaena-features
/// CommunityPulse — Live-Aktivitaet-Snapshot der Nachbarschaft.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';

class CommunityPulse extends StatelessWidget {
  const CommunityPulse({super.key, required this.posts});
  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final last24h = posts.where((p) {
      return today.difference(p.createdAt).inHours < 24;
    }).length;
    final helpRequests =
        posts.where((p) => p.type == 'help_request').length;
    final helpOffers =
        posts.where((p) => p.type == 'help_offered').length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.leben,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('home.communityPulse'.tr(),
                  style: AppTypography.label(
                      size: 10, color: AppColors.lebenSoft)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PulseStat(
                    label: 'Neue Posts (24h)',
                    value: '$last24h',
                    icon: LucideIcons.trendingUp,
                    color: AppColors.amber),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PulseStat(
                    label: 'Hilfe gesucht',
                    value: '$helpRequests',
                    icon: LucideIcons.heart,
                    color: AppColors.herzrotWarm),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PulseStat(
                    label: 'Hilfe da',
                    value: '$helpOffers',
                    icon: LucideIcons.helpingHand,
                    color: AppColors.lebenSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseStat extends StatelessWidget {
  const _PulseStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.mono(size: 18, color: AppColors.ink)),
          Text(label,
              style: AppTypography.label(size: 8, color: color)),
        ],
      ),
    );
  }
}
