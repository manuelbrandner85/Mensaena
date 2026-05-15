import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_avatar.dart';
import '../../core/widgets/cinema_bottom_nav.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_stat.dart';
import '../../core/widgets/cinema_tabs.dart';
import '../../core/widgets/glow_button.dart';
import '../../core/widgets/trust_stars.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final resolvedId = widget.userId == 'me' ? me?.id : widget.userId;
    final profile = resolvedId == null
        ? null
        : ref.watch(profileByIdProvider(resolvedId));
    final isMe = me?.id == resolvedId;

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'PROFIL'),
      bottomNavigationBar: CinemaBottomNav(
        currentIndex: 4,
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
              GoRouter.of(context).go('/chat');
              break;
            case 4:
              break;
          }
        },
      ),
      body: SafeArea(
        child: profile == null
            ? const Center(child: Text('Kein Profil.'))
            : profile.when(
                loading: () => const CinemaLoadingSkeleton(),
                error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
                data: (p) {
                  if (p == null) {
                    return Center(
                      child: Text(
                        'Profil nicht gefunden.',
                        style: MnTypography.body(color: MnColors.mute),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      _Header(profile: p, isMe: isMe),
                      CinemaTabs(
                        controller: _tabs,
                        labels: const [
                          'Beitraege',
                          'Bewertungen',
                          'Gruppen',
                          'Aktivitaet',
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabs,
                          children: [
                            _EmptyTab(icon: LucideIcons.fileText, label: 'Beitraege folgen.'),
                            _EmptyTab(icon: LucideIcons.star, label: 'Bewertungen folgen.'),
                            _EmptyTab(icon: LucideIcons.users, label: 'Gruppen folgen.'),
                            _EmptyTab(icon: LucideIcons.activity, label: 'Aktivitaet folgt.'),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool isMe;
  const _Header({required this.profile, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: const BoxDecoration(
        color: MnColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(MnDimensions.radiusModal)),
      ),
      child: Column(
        children: [
          CinemaAvatar(
            imageUrl: profile['avatar_url'] as String?,
            displayName: profile['full_name'] as String?,
            size: AvatarSize.xl,
          ),
          const SizedBox(height: 12),
          Text(
            (profile['full_name'] as String?) ?? 'Nachbar*in',
            style: MnTypography.display(size: 24),
          ),
          if ((profile['location'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              profile['location'] as String,
              style: MnTypography.body(color: MnColors.mute, size: 13),
            ),
          ],
          if ((profile['bio'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              profile['bio'] as String,
              style: MnTypography.body(color: MnColors.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          const TrustStars(rating: 4.5, size: 22),
          const SizedBox(height: 12),
          if (isMe)
            GlowButton(
              label: 'Bearbeiten',
              variant: GlowVariant.ghost,
              compact: true,
              onPressed: () => GoRouter.of(context).push(
                '/profile/${profile['id']}/edit',
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              CinemaStat(value: 0, label: 'Beitraege'),
              CinemaStat(value: 0, label: 'Geholfen'),
              CinemaStat(value: 0, label: 'Erhalten'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: MnColors.mute.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(label, style: MnTypography.body(color: MnColors.mute)),
        ],
      ),
    );
  }
}
