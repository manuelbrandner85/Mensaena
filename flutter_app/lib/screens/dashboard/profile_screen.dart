import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/profile.dart';
import '../../repositories/profiles_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// Profil-Screen: eigenes oder fremdes (per userId). Trust-Score + Level
/// + Bio + Standort + Skills + Actions.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.userId, super.key});

  /// null = eigenes Profil.
  final String? userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<Profile?>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.userId == null
        ? ProfilesRepository.getMine()
        : ProfilesRepository.getById(widget.userId!);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: widget.userId == null ? 'Mein Profil' : 'Profil',
      currentRoute: '/dashboard/profile',
      body: SafeArea(
        child: FutureBuilder<Profile?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.amber),
              );
            }
            final p = snap.data;
            if (p == null) {
              return Center(
                child: Text(
                  'Profil nicht gefunden.',
                  style: AppTypography.caption(),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Header(profile: p),
                const SizedBox(height: 24),
                if (p.bio != null && p.bio!.isNotEmpty) ...[
                  Text('Über', style: AppTypography.label(size: 10)),
                  const SizedBox(height: 6),
                  Text(
                    p.bio!,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.inkSoft,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                _StatsGrid(profile: p),
                const SizedBox(height: 18),
                if (p.skills.isNotEmpty) ...[
                  Text('Skills', style: AppTypography.label(size: 10)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: p.skills
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.elevated,
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                s,
                                style: AppTypography.body(
                                  size: 11,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                ],
                if (widget.userId == null) ...[
                  OutlinedButton.icon(
                    onPressed: () => context.go('/dashboard/settings'),
                    icon: const Icon(LucideIcons.settings, size: 16),
                    label: const Text('Einstellungen'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.surface,
          backgroundImage: profile.avatarUrl != null
              ? NetworkImage(profile.avatarUrl!)
              : null,
          child: profile.avatarUrl == null
              ? Text(
                  (profile.name ?? '?').substring(0, 1).toUpperCase(),
                  style: AppTypography.display(
                    size: 28,
                    color: AppColors.amber,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName ?? profile.name ?? 'Nachbar:in',
                style: AppTypography.display(
                  size: 22,
                  color: AppColors.ink,
                ),
              ),
              if (profile.location != null)
                Text(
                  profile.location!,
                  style: AppTypography.body(size: 13, color: AppColors.mute),
                ),
              const SizedBox(height: 8),
              _TrustBadge(
                  score: profile.trustScore, count: profile.trustScoreCount),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.score, required this.count});
  final int score;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = score >= 4
        ? AppColors.trust
        : score >= 3
            ? AppColors.amber
            : AppColors.mute;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.star, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            'Trust $score · $count Bewertungen',
            style: AppTypography.label(size: 10, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Stat(
            icon: LucideIcons.zap,
            label: 'Impact',
            value: '${profile.impactScore}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            icon: LucideIcons.trophy,
            label: 'Punkte',
            value: '${profile.points}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            icon: LucideIcons.heart,
            label: 'Spenden',
            value: '${profile.donationCount}',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.amber),
          const SizedBox(height: 8),
          Text(value, style: AppTypography.mono(size: 18)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.label(size: 9)),
        ],
      ),
    );
  }
}
