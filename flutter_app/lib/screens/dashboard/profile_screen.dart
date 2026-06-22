import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../widgets/profile/send_thank_you_sheet.dart';
import '../../widgets/profile/send_voicemail_sheet.dart';
import '../../widgets/profile/status_editor_sheet.dart';
import 'call/scheduled_calls_screen.dart';
import 'package:share_plus/share_plus.dart';

import '../../widgets/effects/bloom.dart';
import '../../widgets/effects/tilt_card.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../models/profile.dart';
import '../../repositories/challenges_repository.dart';
import '../../repositories/content_reports_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../repositories/posts_repository.dart';
import '../../repositories/trust_ratings_repository.dart';
import '../../repositories/user_blocks_repository.dart';

import '../../services/supabase_service.dart';
import '../../repositories/mega_repositories.dart';
import '../../widgets/dashboard/activity_heatmap_widget.dart';
import '../../widgets/profile/friend_request_button.dart';
import '../../widgets/profile/qr_share_sheet.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/empty_state_card.dart';
import '../../widgets/shared/verified_badge.dart';
import '../../widgets/shared/post_card.dart';
import '../../widgets/shared/sparkline.dart';
import '../../widgets/shared/app_snackbar.dart';

/// V4: Trust-Score-Verlauf (laufender Durchschnitt aus trust_ratings).
final _trustHistoryProvider =
    FutureProvider.family.autoDispose<List<double>, String>(
  (ref, userId) => TrustRatingsRepository.scoreHistory(userId),
);

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

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Future<Profile?>? _future;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    // Bug-Fix: leerer/ungueltiger userId-Param wurde als "fremdes Profil"
    // interpretiert, getById('') gab null zurueck → "Profil nicht gefunden".
    // Jetzt: leerer String == eigenes Profil.
    final uid = widget.userId;
    final isOwn = uid == null || uid.isEmpty;
    _future = isOwn
        ? ProfilesRepository.getMine()
        : ProfilesRepository.getById(uid);
    _tab = TabController(length: 4, vsync: this);
    // F37: Profile-View aufzeichnen wenn fremdes Profil (1x pro Tag).
    if (!isOwn) {
      ProfileViewsRepository.recordView(uid);
    }
  }

  bool get _isOwnProfile {
    final uid = widget.userId;
    return uid == null || uid.isEmpty;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMe = _isOwnProfile;
    return DashboardScaffold(
      title:
          isMe ? 'profile.myProfile'.tr() : 'profile.otherProfile'.tr(),
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
            // Robust own-profile-check: zusätzlich zur Route-Heuristik
            // (widget.userId leer) auch profile.id gegen aktuelle Session
            // vergleichen. Sonst zeigt /dashboard/profile/<my-uid> Block-/
            // Report-Buttons auf dem EIGENEN Profil.
            final myUid = SupabaseService.currentUser?.id;
            final effectiveIsMe =
                isMe || (p != null && myUid != null && p.id == myUid);
            if (p == null) {
              // Wenn eigenes Profil + nicht gefunden: vermutlich JWT abgelaufen
              // oder profile-Row fehlt. Biete Retry-Button + Logout-Hinweis.
              final notLoggedIn =
                  SupabaseService.currentUser == null;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.userX,
                          size: 32, color: AppColors.mute),
                      const SizedBox(height: 12),
                      Text(
                        notLoggedIn
                            ? 'profile.notLoggedIn'.tr()
                            : 'profile.loadError'.tr(),
                        style: AppTypography.body(
                            size: 14, color: AppColors.inkSoft),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () async {
                          // Session refresh + retry
                          await SupabaseService.ensureFreshSession();
                          setState(() {
                            _future = isMe
                                ? ProfilesRepository.getMine()
                                : ProfilesRepository.getById(widget.userId!);
                          });
                        },
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        label: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                ),
              );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
              key: ValueKey('profile-${p.id}'),
              children: [
                // Cinema-Cover: dezenter Bronze-Spotlight hinter dem Header
                // (der Header scrollt nicht → kein Parallax, dafür ein
                // filmisches Cover-Backdrop).
                // Cover-Banner (echtes Cover-Bild oder Bronze-Verlauf) — der
                // Avatar im _Header überlappt es nach oben (moderner Hero).
                _ProfileBanner(profile: p),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _Header(profile: p, isMe: effectiveIsMe),
                ),
                TabBar(
                  controller: _tab,
                  indicatorColor: AppColors.amber,
                  labelColor: AppColors.amber,
                  unselectedLabelColor: AppColors.inkSoft,
                  labelStyle: AppTypography.label(size: 11),
                  unselectedLabelStyle: AppTypography.label(size: 11),
                  tabs: [
                    Tab(text: 'profile.tabs.about'.tr()),
                    Tab(text: 'profile.tabs.posts'.tr()),
                    Tab(text: 'profile.tabs.ratings'.tr()),
                    Tab(text: 'profile.tabs.badges'.tr()),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _AboutTab(profile: p, isMe: effectiveIsMe),
                      _PostsTab(userId: p.id),
                      _RatingsTab(userId: p.id),
                      _BadgesTab(userId: p.id),
                    ],
                  ),
                ),
              ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.profile, required this.isMe});
  final Profile profile;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    // Klarere Hierarchie (weniger „überladen"): Kennzahlen → persönliche
    // Inhalte (Bio, Skills) → sekundäre/dichte Blöcke (Detail-Stats, Aktivitäts-
    // Heatmap) zuletzt.
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ProfileStatsBar(userId: p.id),
        const SizedBox(height: 18),
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          Text('profile.about'.tr(), style: AppTypography.label(size: 10)),
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
        if (p.skills.isNotEmpty) ...[
          Text('nav.skills'.tr(), style: AppTypography.label(size: 10)),
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
        // Aktivität zuletzt (dicht, sekundär). Detail-Stats (Impact/Points/
        // Spenden) entfernt: Spenden = goldenes Herz im Header, Impact/Points
        // im Badges-Tab + Leaderboard — eine ruhige Stats-Bar genügt.
        ActivityHeatmapWidget(userId: p.id),
        const SizedBox(height: 18),
        if (isMe) ...[
          OutlinedButton.icon(
            onPressed: () => context.go('/dashboard/settings'),
            icon: const Icon(LucideIcons.settings, size: 16),
            label: Text('common.settings'.tr()),
          ),
        ],
      ],
    );
  }
}

class _ProfileStatsBar extends StatefulWidget {
  const _ProfileStatsBar({required this.userId});
  final String userId;

  @override
  State<_ProfileStatsBar> createState() => _ProfileStatsBarState();
}

class _ProfileStatsBarState extends State<_ProfileStatsBar> {
  late Future<_StatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsData> _load() async {
    try {
      // PERF (Audit): Vorher zog jede Stat-Query ALLE matching Rows (id-only,
      // aber bei Power-Usern hundert+) — der Profile-Screen wartete bis zu
      // 1.2s auf 4 sequenzielle Roundtrips. Jetzt:
      //   - Posts + Group-Memberships: head-only count() statt Row-Liste.
      //   - Challenges: filter direkt auf "nicht completed" → kleinere Liste.
      //   - Timebank-Hours: hours + giver_id genügt (status='confirmed'
      //     filtert serverseitig; receiver_id ist redundant weil die
      //     OR-Bedingung garantiert dass userId einer der beiden ist).
      final stats = await ProfilesRepository.publicStats(widget.userId);
      return _StatsData(
        postsCount: stats.posts,
        groupsCount: stats.groups,
        activeChallenges: stats.activeChallenges,
        hoursGiven: stats.hoursGiven,
        hoursReceived: stats.hoursReceived,
      );
    } catch (_) {
      return const _StatsData(
        postsCount: 0,
        groupsCount: 0,
        activeChallenges: 0,
        hoursGiven: 0,
        hoursReceived: 0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StatsData>(
      future: _future,
      builder: (context, snap) {
        final s = snap.data ??
            const _StatsData(
              postsCount: 0,
              groupsCount: 0,
              activeChallenges: 0,
              hoursGiven: 0,
              hoursReceived: 0,
            );
        final netto = (s.hoursGiven - s.hoursReceived);
        return Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: LucideIcons.clock,
                color: AppColors.bronze,
                value: '${netto.toStringAsFixed(1)}h',
                label: 'profile.stats.timebank'.tr(),
                sub: '${s.hoursGiven.toStringAsFixed(0)}h ↑ ${s.hoursReceived.toStringAsFixed(0)}h ↓',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatTile(
                icon: LucideIcons.users2,
                color: AppColors.tealSoft,
                value: '${s.groupsCount}',
                label: 'profile.stats.groups'.tr(),
                sub: s.groupsCount == 1
                    ? 'profile.stats.membership'.tr()
                    : 'profile.stats.memberships'.tr(),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatTile(
                icon: LucideIcons.trophy,
                color: AppColors.amber,
                value: '${s.activeChallenges}',
                label: 'profile.stats.challenges'.tr(),
                sub: 'profile.stats.active'.tr(),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _StatTile(
                icon: LucideIcons.fileText,
                color: AppColors.lebenSoft,
                value: '${s.postsCount}',
                label: 'profile.stats.posts'.tr(),
                sub: 'profile.stats.active'.tr(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatsData {
  const _StatsData({
    required this.postsCount,
    required this.groupsCount,
    required this.activeChallenges,
    required this.hoursGiven,
    required this.hoursReceived,
  });
  final int postsCount;
  final int groupsCount;
  final int activeChallenges;
  final double hoursGiven;
  final double hoursReceived;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.sub,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.mono(
              size: 16,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            style: AppTypography.label(size: 8, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              size: 9,
              color: AppColors.mute,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostsTab extends StatefulWidget {
  const _PostsTab({required this.userId});
  final String userId;

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  late Future<List<Post>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Post>> _load() async {
    try {
      return PostsRepository.listByUser(widget.userId);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Post>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          );
        }
        final list = snap.data ?? const <Post>[];
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyStateCard(
                icon: LucideIcons.fileText,
                title: 'profile.noPosts'.tr(),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, i) => PostCard(post: list[i]),
        );
      },
    );
  }
}

class _RatingsTab extends StatefulWidget {
  const _RatingsTab({required this.userId});
  final String userId;

  @override
  State<_RatingsTab> createState() => _RatingsTabState();
}

class _RatingsTabState extends State<_RatingsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      return TrustRatingsRepository.getReceivedFor(widget.userId);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          );
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return Center(
            child: Text('profile.noRatings'.tr(),
                style: AppTypography.caption()),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final r = list[i];
            final stars = (r['stars'] as num?)?.toInt() ?? 0;
            final comment = r['comment'] as String?;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (var s = 0; s < 5; s++)
                        Icon(LucideIcons.star,
                            size: 14,
                            color: s < stars
                                ? AppColors.amber
                                : AppColors.mute),
                    ],
                  ),
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(comment,
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.inkSoft,
                            height: 1.4)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BadgesTab extends ConsumerWidget {
  const _BadgesTab({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mineAsync = ref.watch(myBadgesProvider);
    final allAsync = ref.watch(allBadgesProvider);
    return mineAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.amber),
      ),
      error: (_, __) => Center(
        child: Text('profile.loadError'.tr(), style: AppTypography.caption()),
      ),
      data: (mine) {
        if (mine.isEmpty) {
          return Center(
            child: Text('profile.noBadges'.tr(),
                style: AppTypography.caption()),
          );
        }
        final allBadges = allAsync.value ?? const [];
        final earnedIds = <String>{for (final ub in mine) ub.badgeId};
        final earned = allBadges.where((b) => earnedIds.contains(b.id));
        return GridView(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 130,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
          ),
          children: [
            for (final b in earned)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.10),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.award,
                        color: AppColors.amber, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      b.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTypography.body(
                          size: 11,
                          color: AppColors.ink,
                          weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Cover-Banner über dem Profil-Header: zeigt das echte Cover-Bild (falls
/// gesetzt) mit dezentem Scrim für Lesbarkeit, sonst einen Bronze-Verlauf.
/// Voll-bündig (kein Seitenrand) — der Avatar im _Header überlappt es.
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final cover = profile.coverUrl;
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: cover == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.bronze.withValues(alpha: 0.22),
                  AppColors.surface.withValues(alpha: 0.0),
                ],
              )
            : null,
        border: Border(
          bottom:
              BorderSide(color: AppColors.bronze.withValues(alpha: 0.16)),
        ),
      ),
      child: cover == null
          ? null
          : Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 240),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
                // Scrim unten → der überlappende Avatar bleibt klar abgesetzt.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.28),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.isMe});
  final Profile profile;
  // isMe wird vom Parent (ProfileScreen) explizit reingereicht — basiert
  // auf widget.userId == null/empty. Robuster als
  // SupabaseService.currentUser?.id == profile.id zu vergleichen, weil
  // das bei einem kurzen Auth-Refresh false werden koennte.
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar überlappt das Cover-Banner (modern, Apple-/LinkedIn-Stil)
            // mit hellem Ring zur sauberen Trennung vom Banner. Tippen führt
            // zum Edit-Screen (dort funktioniert der verifizierte Foto-Upload).
            Transform.translate(
              offset: const Offset(0, -34),
              child: GestureDetector(
                onTap: isMe
                    ? () => context.push('/dashboard/profile/edit')
                    : null,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppColors.lightVoid, width: 3),
                        ),
                      ),
                      child: Hero(
                        tag: 'profile-avatar-${profile.id}',
                        child: Bloom(
                          color: AppColors.bronze,
                          intensity: 0.5,
                          radius: 24,
                          child: TiltCard(
                            intensity: 1.2,
                            borderRadius: 999,
                            child: profile.avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: profile.avatarUrl!,
                                    fadeInDuration:
                                        const Duration(milliseconds: 200),
                                    imageBuilder: (_, img) => CircleAvatar(
                                      radius: 40,
                                      backgroundColor: AppColors.surface,
                                      backgroundImage: img,
                                    ),
                                    placeholder: (_, __) => const CircleAvatar(
                                      radius: 40,
                                      backgroundColor: AppColors.surface,
                                    ),
                                    errorWidget: (_, __, ___) => CircleAvatar(
                                      radius: 40,
                                      backgroundColor: AppColors.surface,
                                      child: Text(
                                        (profile.name ?? '?')
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: AppTypography.display(
                                          size: 30,
                                          color: AppColors.amber,
                                        ),
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 40,
                                    backgroundColor: AppColors.surface,
                                    child: Text(
                                      (profile.name ?? '?')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: AppTypography.display(
                                        size: 30,
                                        color: AppColors.amber,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    if (isMe)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.lightVoid,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            LucideIcons.camera,
                            size: 12,
                            color: Colors.black,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName ??
                              profile.name ??
                              'common.neighbour'.tr(),
                          style: AppTypography.display(
                            size: 22,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      VerifiedBadge.inline(profile: profile, size: 18),
                      // Goldenes Herz: Dankeschön für Spender:innen (donorTier≥1).
                      if (profile.donorTier >= 1) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'profile.supporterHeart'.tr(),
                          child: Icon(
                            Icons.favorite,
                            size: 18,
                            color: AppColors.amber,
                            shadows: [
                              Shadow(
                                color: AppColors.amber.withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isMe) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      FriendRequestButton(userId: profile.id),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'scheduled_calls.create_title'.tr(),
                        onPressed: () => ScheduleCallSheet.show(
                          context,
                          calleeId: profile.id,
                          calleeName:
                              profile.displayName ?? profile.name ?? 'mensaena',
                        ),
                        icon: const Icon(LucideIcons.calendarPlus,
                            size: 18, color: AppColors.bronze),
                      ),
                      IconButton(
                        tooltip: 'voicemail.send_to'.tr(),
                        onPressed: () => SendVoicemailSheet.show(
                          context,
                          calleeId: profile.id,
                          calleeName:
                              profile.displayName ?? profile.name ?? 'mensaena',
                        ),
                        icon: const Icon(LucideIcons.voicemail,
                            size: 18, color: AppColors.bronze),
                      ),
                      // F71: Danke-Karte senden
                      IconButton(
                        tooltip: 'thanks.sheetTitle'.tr(),
                        onPressed: () => SendThankYouSheet.show(
                          context,
                          receiverId: profile.id,
                          receiverName: profile.displayName ??
                              profile.name ??
                              'mensaena',
                        ),
                        icon: const Icon(LucideIcons.heart,
                            size: 18, color: AppColors.amber),
                      ),
                    ]),
                  ],
                  if (profile.location != null)
                    Text(
                      profile.location!,
                      style: AppTypography.body(
                          size: 13, color: AppColors.mute),
                    ),
                  if (profile.hasActiveStatus) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: GestureDetector(
                        onTap: isMe
                            ? () => StatusEditorSheet.show(context)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(profile.statusEmoji ?? '💬',
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                profile.statusText!,
                                style: AppTypography.body(
                                    size: 13, color: AppColors.inkSoft),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (isMe) ...[
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => StatusEditorSheet.show(context),
                      icon: const Icon(LucideIcons.smile, size: 14),
                      label: Text('status.set'.tr()),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.bronze,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _TrustBadge(
                      score: profile.trustScore,
                      count: profile.trustScoreCount,
                      userId: profile.id),
                  _TrustHistory(userId: profile.id),
                  // Entdoppelung: das detaillierte Verifikations-Panel nur im
                  // EIGENEN Profil (aktionierbar — Verifizierung vervollständigen);
                  // bei anderen genügt das ✓-Badge neben dem Namen.
                  if (isMe) ...[
                    const SizedBox(height: 12),
                    VerifiedDetailsPanel(profile: profile),
                  ],
                ],
              ),
            ),
            // Teilen + QR aus der Kopf-Row ausgelagert (siehe Aktionszeile
            // unten) → Namensspalte bekommt volle Breite, ruhigerer Header.
          ],
        ),
        // Rechtsbündige, dezente Aktionszeile statt gequetschter Icons oben.
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'profile.share'.tr(),
                onPressed: () {
                  final name =
                      profile.displayName ?? profile.name ?? 'Mensaena';
                  final url =
                      'https://www.mensaena.de/get/profile/${profile.id}';
                  Share.share(
                    'profile.shareMessage'
                        .tr(namedArgs: {'name': name, 'url': url}),
                    subject: name,
                  );
                },
                icon: const Icon(LucideIcons.share2,
                    size: 18, color: AppColors.mute),
              ),
              IconButton(
                tooltip: 'profile.qr_code'.tr(),
                onPressed: () => QrShareSheet.show(
                  context,
                  userId: profile.id,
                  displayName:
                      profile.displayName ?? profile.name ?? 'Mensaena',
                ),
                icon: const Icon(LucideIcons.qrCode,
                    size: 18, color: AppColors.mute),
              ),
            ],
          ),
        ),
        if (isMe) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/dashboard/profile/edit'),
                  icon: const Icon(LucideIcons.edit2, size: 14),
                  label: Text('profile.editProfile'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bronze,
                    side: BorderSide(
                        color: AppColors.bronze.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/dashboard/profile/saved'),
                  icon: const Icon(LucideIcons.bookmark, size: 14),
                  label: Text('profile.saved'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.amber,
                    side: BorderSide(
                        color: AppColors.amber.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ),
          // V3: Vertrauens-Pfad — Quest mit Schritten die Trust aufbauen.
          _TrustPathQuest(profile: profile),
        ] else ...[
          const SizedBox(height: 12),
          _OtherUserActions(targetUserId: profile.id),
        ],
      ],
    );
  }
}

/// 3-Punkte-Menü für fremde Profile: Blockieren + Melden.
/// 1:1 zur Web-Implementierung in OtherUserProfile.tsx.
class _OtherUserActions extends StatefulWidget {
  const _OtherUserActions({required this.targetUserId});
  final String targetUserId;

  @override
  State<_OtherUserActions> createState() => _OtherUserActionsState();
}

class _OtherUserActionsState extends State<_OtherUserActions> {
  bool _busy = false;

  Future<void> _confirmBlock() async {
    // Drei Optionen: Abbrechen · 24 Std. stummschalten (sanft, läuft aus) ·
    // dauerhaft blockieren.
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('profile.blockTitle'.tr(),
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text(
            'profile.blockOrMuteBody'.tr(),
            style:
                AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'mute'),
            style: TextButton.styleFrom(foregroundColor: AppColors.amber),
            child: Text('profile.mute24h'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'block'),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: Text('profile.block'.tr()),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    setState(() => _busy = true);
    final ok = action == 'mute'
        ? await UserBlocksRepository.muteFor(widget.targetUserId)
        : await UserBlocksRepository.block(widget.targetUserId);
    if (!mounted) return;
    setState(() => _busy = false);
    final msg = !ok
        ? 'profile.blockFailed'.tr()
        : (action == 'mute'
            ? 'profile.userMuted24h'.tr()
            : 'profile.userBlocked'.tr());
    AppSnackBar.info(context, msg);
  }

  Future<void> _showReportDialog() async {
    // value = kanonische (DE) Kennung in DB; labelKey = übersetzte Anzeige.
    const reasons = <({String value, String labelKey})>[
      (value: 'Spam', labelKey: 'posts.reasonSpam'),
      (value: 'Belästigung', labelKey: 'posts.reasonHarassment'),
      (value: 'Hass / Diskriminierung', labelKey: 'postCard.reasonHate'),
      (value: 'Gewalt', labelKey: 'postCard.reasonViolence'),
      (value: 'Falsche Informationen', labelKey: 'posts.reasonFalse'),
      (value: 'Anstößige Inhalte', labelKey: 'posts.reasonOffensive'),
      (value: 'Anderer Grund', labelKey: 'posts.reasonOther'),
    ];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('profile.reportTitle'.tr(),
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('profile.reportPickReason'.tr(),
                style: AppTypography.body(
                    size: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 10),
            for (final r in reasons)
              ListTile(
                dense: true,
                title: Text(r.labelKey.tr(),
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink)),
                onTap: () => Navigator.pop(ctx, r.value),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await ContentReportsRepository.report(
      contentType: 'user',
      contentId: widget.targetUserId,
      reason: selected,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    AppSnackBar.info(context, ok ? 'posts.reportSubmitted'.tr() : 'posts.reportFailed'.tr());
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _showReportDialog,
            icon: const Icon(LucideIcons.flag, size: 14),
            label: Text('profile.report'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.amber,
              side: BorderSide(
                  color: AppColors.amber.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _confirmBlock,
            icon: const Icon(LucideIcons.ban, size: 14),
            label: Text('profile.block'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.herzrot,
              side: BorderSide(
                  color: AppColors.herzrot.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}

/// V3: Vertrauens-Pfad — eine kleine Quest die dem User zeigt, wie er
/// Schritt für Schritt Vertrauen aufbaut. Alle Schritte sind aus dem
/// Profil ableitbar (keine Extra-Queries). Erscheint nur solange noch
/// nicht alle Schritte erledigt sind → verschwindet als sanftes Ziel.
class _TrustPathQuest extends StatelessWidget {
  const _TrustPathQuest({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final hasLocation = (profile.homeCity != null &&
            profile.homeCity!.isNotEmpty) ||
        profile.latitude != null;
    final steps = <({String label, bool done, String route})>[
      (
        label: 'trustPath.avatar'.tr(),
        done: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty,
        route: '/dashboard/profile/edit',
      ),
      (
        label: 'trustPath.bio'.tr(),
        done: profile.bio != null && profile.bio!.trim().isNotEmpty,
        route: '/dashboard/profile/edit',
      ),
      (
        label: 'trustPath.location'.tr(),
        done: hasLocation,
        route: '/dashboard/profile/edit',
      ),
      (
        label: 'trustPath.verifyEmail'.tr(),
        done: profile.verifiedEmail || profile.isVerified == true,
        route: '/dashboard/account',
      ),
      (
        label: 'trustPath.firstRating'.tr(),
        done: profile.trustScoreCount > 0,
        route: '/dashboard/posts',
      ),
    ];
    final doneCount = steps.where((s) => s.done).length;
    // Alle erledigt → Quest ausblenden (Ziel erreicht).
    if (doneCount == steps.length) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.bronze.withValues(alpha: 0.12),
            AppColors.amber.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck,
                  size: 16, color: AppColors.bronze),
              const SizedBox(width: 8),
              Expanded(
                child: Text('trustPath.title'.tr(),
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
              ),
              Text('$doneCount/${steps.length}',
                  style: AppTypography.mono(
                      size: 12, color: AppColors.bronze)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: doneCount / steps.length,
              minHeight: 5,
              backgroundColor: AppColors.line,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.bronze),
            ),
          ),
          const SizedBox(height: 10),
          for (final s in steps)
            InkWell(
              onTap: s.done ? null : () => context.push(s.route),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      s.done
                          ? LucideIcons.checkCircle2
                          : LucideIcons.circle,
                      size: 16,
                      color:
                          s.done ? AppColors.leben : AppColors.mute,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(s.label,
                          style: AppTypography.body(
                            size: 13,
                            color: s.done
                                ? AppColors.mute
                                : AppColors.ink,
                          )),
                    ),
                    if (!s.done)
                      const Icon(LucideIcons.chevronRight,
                          size: 14, color: AppColors.mute),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// V4: Trust-Score-Verlauf als Sparkline. Erscheint nur wenn genug
/// Bewertungen für einen sinnvollen Trend da sind (>= 2).
class _TrustHistory extends ConsumerWidget {
  const _TrustHistory({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_trustHistoryProvider(userId));
    final data = async.asData?.value ?? const <double>[];
    if (data.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('profile.trustTrend'.tr(),
              style: AppTypography.label(size: 9, color: AppColors.mute)),
          const SizedBox(height: 4),
          Sparkline(values: data, color: AppColors.trust, height: 40),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.score,
    required this.count,
    required this.userId,
  });
  final int score;
  final int count;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final color = score >= 4
        ? AppColors.trust
        : score >= 3
            ? AppColors.amber
            : AppColors.mute;
    return InkWell(
      onTap: () => _showBreakdown(context),
      borderRadius: BorderRadius.circular(999),
      child: Container(
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
              'profile.trustBadge'.tr(namedArgs: {
                'score': '$score',
                'count': '$count',
              }),
              style: AppTypography.label(size: 10, color: color),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.info, size: 10, color: color),
          ],
        ),
      ),
    );
  }

  void _showBreakdown(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TrustBreakdownSheet(userId: userId),
    );
  }
}

class _TrustBreakdownSheet extends StatefulWidget {
  const _TrustBreakdownSheet({required this.userId});
  final String userId;

  @override
  State<_TrustBreakdownSheet> createState() => _TrustBreakdownSheetState();
}

class _TrustBreakdownSheetState extends State<_TrustBreakdownSheet> {
  Future<Map<String, dynamic>?>? _future;

  @override
  void initState() {
    super.initState();
    _future = TrustRatingsRepository.getBreakdown(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final data = snap.data ?? const <String, dynamic>{};
        final avg = (data['avg_score'] as num?)?.toDouble() ??
            (data['average_score'] as num?)?.toDouble() ??
            0;
        final total = (data['total_ratings'] as int?) ?? 0;
        final dist = data['score_distribution'] as Map<String, dynamic>?;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(LucideIcons.shieldCheck,
                      size: 18, color: AppColors.trust),
                  const SizedBox(width: 8),
                  Text('profile.trustBreakdown'.tr(),
                      style: AppTypography.display(
                          size: 18, color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 14),
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        color: AppColors.amber),
                  ),
                )
              else if (total == 0)
                Text(
                  'profile.noRatingsForUser'.tr(),
                  style: AppTypography.body(
                      size: 13, color: AppColors.mute),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      avg.toStringAsFixed(1),
                      style: AppTypography.display(
                          size: 38, color: AppColors.amber),
                    ),
                    const SizedBox(width: 6),
                    Text('/ 5',
                        style: AppTypography.body(
                            size: 14, color: AppColors.mute)),
                    const SizedBox(width: 12),
                    Text(
                        'profile.ratingsOutOf'
                            .tr(namedArgs: {'total': '$total'}),
                        style: AppTypography.body(
                            size: 12, color: AppColors.inkSoft)),
                  ],
                ),
                const SizedBox(height: 16),
                if (dist != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [5, 4, 3, 2, 1].map((star) {
                      final count = (dist['$star'] as int?) ?? 0;
                      final pct = total > 0 ? count / total : 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Row(
                                children: [
                                  Text('$star',
                                      style: AppTypography.body(
                                          size: 12,
                                          color: AppColors.inkSoft)),
                                  const SizedBox(width: 2),
                                  const Icon(LucideIcons.star,
                                      size: 10,
                                      color: AppColors.amber),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 6,
                                  backgroundColor: AppColors.elevated,
                                  valueColor:
                                      const AlwaysStoppedAnimation(
                                          AppColors.amber),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 32,
                              child: Text('$count',
                                  textAlign: TextAlign.end,
                                  style: AppTypography.mono(
                                      size: 11,
                                      color: AppColors.mute)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                Text(
                  'profile.trustScoreExplain'.tr(),
                  style: AppTypography.body(
                      size: 11, color: AppColors.mute, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// _StatsGrid + _Stat entfernt (Profil-Entschlackung): die Detail-Stats
// (Impact/Points/Spenden) waren redundant zur Stats-Bar; Spenden zeigt jetzt
// das goldene Herz im Header, Impact/Points sind im Badges-Tab + Leaderboard.
