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
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_select.dart';
import '../../core/widgets/cinema_sheet.dart';
import '../../core/widgets/cinema_stat.dart';
import '../../core/widgets/cinema_tabs.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../core/widgets/trust_stars.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase/database_service.dart';
import 'widgets/trust_rating_form.dart';

/// Profil-Tabs Provider (Beitraege / Gruppen / Aktivitaet).
/// `userRatingsProvider` ist in trust_rating_form.dart definiert.
final userPostsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return db.listUserPosts(userId);
});

final userGroupsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return db.listUserGroups(userId);
});

final userActivityProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return db.listUserActivity(userId);
});

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
      appBar: CinemaAppBar(
        title: 'PROFIL',
        actions: [
          if (!isMe && resolvedId != null && me != null)
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.moreVertical, color: MnColors.inkSoft),
              color: MnColors.raised,
              onSelected: (v) {
                final p = profile?.asData?.value;
                final name = (p?['name'] as String?) ?? 'Nachbar*in';
                if (v == 'report') {
                  _openReportSheet(resolvedId, name);
                } else if (v == 'block') {
                  _openBlockConfirm(resolvedId, name);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      const Icon(LucideIcons.flag, size: 16, color: MnColors.amber),
                      const SizedBox(width: 8),
                      Text('Melden', style: MnTypography.body(color: MnColors.ink)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      const Icon(LucideIcons.userX, size: 16, color: MnColors.herzrot),
                      const SizedBox(width: 8),
                      Text('Blockieren', style: MnTypography.body(color: MnColors.ink)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
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
                  if (p == null || resolvedId == null) {
                    return Center(
                      child: Text(
                        'Profil nicht gefunden.',
                        style: MnTypography.body(color: MnColors.mute),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      _Header(
                        profile: p,
                        isMe: isMe,
                        onRate: () => _openRateSheet(resolvedId, p),
                      ),
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
                            _PostsTab(userId: resolvedId),
                            _RatingsTab(userId: resolvedId),
                            _GroupsTab(userId: resolvedId),
                            _ActivityTab(userId: resolvedId),
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

  Future<void> _openRateSheet(String ratedId, Map<String, dynamic> profile) {
    return CinemaSheet.show<void>(
      context,
      initialSize: 0.7,
      child: TrustRatingForm(
        ratedUserId: ratedId,
        ratedUserName: profile['name'] as String?,
      ),
    );
  }

  Future<void> _openReportSheet(String targetId, String name) {
    return CinemaSheet.show<void>(
      context,
      initialSize: 0.7,
      child: _ReportUserForm(targetUserId: targetId, targetName: name),
    );
  }

  Future<void> _openBlockConfirm(String targetId, String name) async {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    final confirmed = await CinemaSheet.show<bool>(
      context,
      initialSize: 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$name blockieren?', style: MnTypography.display(size: 22)),
          const SizedBox(height: 8),
          Text(
            'Die Person kann dich nicht mehr kontaktieren und sieht deine Beitraege nicht mehr.',
            style: MnTypography.body(color: MnColors.inkSoft),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GlowButton(
                  label: 'Abbrechen',
                  variant: GlowVariant.ghost,
                  fullWidth: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlowButton(
                  label: 'Blockieren',
                  variant: GlowVariant.crisis,
                  fullWidth: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await db.blockUser(blockerId: me.id, blockedId: targetId);
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: '$name wurde blockiert.',
      );
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Fehler: $e',
      );
    }
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> profile;
  final bool isMe;
  final VoidCallback onRate;
  const _Header({required this.profile, required this.isMe, required this.onRate});

  @override
  Widget build(BuildContext context) {
    final name = (profile['name'] as String?) ??
        (profile['full_name'] as String?) ??
        'Nachbar*in';
    final trustScore = (profile['trust_score'] as num?)?.toDouble() ?? 0.0;
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
            displayName: name,
            size: AvatarSize.xl,
          ),
          const SizedBox(height: 12),
          Text(name, style: MnTypography.display(size: 24)),
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
          TrustStars(rating: trustScore, size: 22),
          const SizedBox(height: 12),
          if (isMe)
            GlowButton(
              label: 'Bearbeiten',
              variant: GlowVariant.ghost,
              compact: true,
              onPressed: () => GoRouter.of(context).push(
                '/profile/${profile['id']}/edit',
              ),
            )
          else
            GlowButton(
              label: 'Bewerten',
              icon: LucideIcons.star,
              variant: GlowVariant.primary,
              compact: true,
              onPressed: onRate,
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

// ─── TAB: Beitraege ─────────────────────────────────────────────────
class _PostsTab extends ConsumerWidget {
  final String userId;
  const _PostsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userPostsProvider(userId));
    return async.when(
      loading: () => const CinemaLoadingSkeleton(),
      error: (e, _) => Center(child: Text('$e', style: MnTypography.body(color: MnColors.herzrot))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: CinemaEmptyState(
              icon: LucideIcons.fileText,
              title: 'Noch keine Beitraege',
              message: 'Hier erscheinen alle eigenen Beitraege.',
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(userPostsProvider(userId).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = rows[i];
              return _PostListCard(post: p);
            },
          ),
        );
      },
    );
  }
}

class _PostListCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostListCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final title = (post['title'] as String?) ?? (post['content'] as String?) ?? '';
    final created = post['created_at'] as String?;
    final type = (post['type'] as String?) ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
      onTap: () => GoRouter.of(context).push('/posts/${post['id']}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MnColors.elevated,
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          border: Border.all(color: MnColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (type.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MnColors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      type,
                      style: MnTypography.label(color: MnColors.teal),
                    ),
                  ),
                const Spacer(),
                Text(
                  _relativeDate(created),
                  style: MnTypography.body(color: MnColors.mute, size: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title.isEmpty ? '(ohne Inhalt)' : title,
              style: MnTypography.body(color: MnColors.ink),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TAB: Bewertungen ───────────────────────────────────────────────
class _RatingsTab extends ConsumerWidget {
  final String userId;
  const _RatingsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userRatingsProvider(userId));
    return async.when(
      loading: () => const CinemaLoadingSkeleton(),
      error: (e, _) => Center(child: Text('$e', style: MnTypography.body(color: MnColors.herzrot))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: CinemaEmptyState(
              icon: LucideIcons.star,
              title: 'Noch keine Bewertungen',
              message: 'Nach Hilfen erscheinen hier die Bewertungen.',
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(userRatingsProvider(userId).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _RatingCard(rating: rows[i]),
          ),
        );
      },
    );
  }
}

class _RatingCard extends StatelessWidget {
  final Map<String, dynamic> rating;
  const _RatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final rater = (rating['rater'] as Map<String, dynamic>?) ?? const {};
    final name = (rater['name'] as String?) ?? 'Nachbar*in';
    final avatar = rater['avatar_url'] as String?;
    final score = (rating['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = rating['comment'] as String?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CinemaAvatar(
                imageUrl: avatar,
                displayName: name,
                size: AvatarSize.sm,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: MnTypography.body(
                        color: MnColors.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _relativeDate(rating['created_at'] as String?),
                      style: MnTypography.body(color: MnColors.mute, size: 12),
                    ),
                  ],
                ),
              ),
              TrustStars(rating: score, size: 16),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment, style: MnTypography.body(color: MnColors.inkSoft)),
          ],
        ],
      ),
    );
  }
}

// ─── TAB: Gruppen ───────────────────────────────────────────────────
class _GroupsTab extends ConsumerWidget {
  final String userId;
  const _GroupsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userGroupsProvider(userId));
    return async.when(
      loading: () => const CinemaLoadingSkeleton(),
      error: (e, _) => Center(child: Text('$e', style: MnTypography.body(color: MnColors.herzrot))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: CinemaEmptyState(
              icon: LucideIcons.users,
              title: 'Noch keine Gruppen',
              message: 'Trete Gruppen bei, um dich zu vernetzen.',
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(userGroupsProvider(userId).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final group = (rows[i]['groups'] as Map<String, dynamic>?) ?? const {};
              final name = (group['name'] as String?) ?? 'Gruppe';
              final desc = group['description'] as String?;
              final gid = group['id'] as String?;
              return InkWell(
                borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                onTap: gid == null
                    ? null
                    : () => GoRouter.of(context).push('/modules/gruppen/$gid'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MnColors.elevated,
                    borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                    border: Border.all(color: MnColors.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: MnColors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.users, color: MnColors.teal, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: MnTypography.body(
                                color: MnColors.ink,
                                weight: FontWeight.w600,
                              ),
                            ),
                            if (desc != null && desc.isNotEmpty)
                              Text(
                                desc,
                                style: MnTypography.body(color: MnColors.mute, size: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── TAB: Aktivitaet ───────────────────────────────────────────────
class _ActivityTab extends ConsumerWidget {
  final String userId;
  const _ActivityTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userActivityProvider(userId));
    return async.when(
      loading: () => const CinemaLoadingSkeleton(),
      error: (e, _) => Center(child: Text('$e', style: MnTypography.body(color: MnColors.herzrot))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: CinemaEmptyState(
              icon: LucideIcons.activity,
              title: 'Keine Aktivitaet',
              message: 'Hier erscheinen Hilfen und Interaktionen.',
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(userActivityProvider(userId).future),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final row = rows[i];
              final post = (row['posts'] as Map<String, dynamic>?) ?? const {};
              final title = (post['title'] as String?) ?? 'Beitrag';
              final status = (row['status'] as String?) ?? '';
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MnColors.elevated,
                  borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                  border: Border.all(color: MnColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: MnColors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.handshake, color: MnColors.amber, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: MnTypography.body(
                              color: MnColors.ink,
                              weight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_statusLabel(status)} • ${_relativeDate(row['created_at'] as String?)}',
                            style: MnTypography.body(color: MnColors.mute, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Report Form ────────────────────────────────────────────────────
class _ReportUserForm extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetName;
  const _ReportUserForm({required this.targetUserId, required this.targetName});

  @override
  ConsumerState<_ReportUserForm> createState() => _ReportUserFormState();
}

class _ReportUserFormState extends ConsumerState<_ReportUserForm> {
  String _reason = 'Spam';
  bool _submitting = false;
  final _descController = TextEditingController();

  static const _reasons = [
    CinemaSelectOption<String>(value: 'Spam', label: 'Spam'),
    CinemaSelectOption<String>(value: 'Beleidigung', label: 'Beleidigung'),
    CinemaSelectOption<String>(value: 'Belaestigung', label: 'Belaestigung'),
    CinemaSelectOption<String>(value: 'Sonstige', label: 'Sonstige'),
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    setState(() => _submitting = true);
    try {
      await db.reportUser(
        reporterId: me.id,
        targetUserId: widget.targetUserId,
        reason: _reason,
        description: _descController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      CinemaToast.show(
        context,
        variant: ToastVariant.success,
        message: 'Meldung gesendet. Danke!',
      );
    } catch (e) {
      if (!mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.error,
        message: 'Fehler: $e',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${widget.targetName} melden', style: MnTypography.display(size: 22)),
        const SizedBox(height: 6),
        Text(
          'Hilf uns, die Nachbarschaft sicher zu halten.',
          style: MnTypography.body(color: MnColors.inkSoft, size: 13),
        ),
        const SizedBox(height: 20),
        CinemaSelect<String>(
          label: 'Grund',
          options: _reasons,
          value: _reason,
          onChanged: (v) => setState(() => _reason = v),
        ),
        const SizedBox(height: 16),
        CinemaInput(
          controller: _descController,
          label: 'Beschreibung (optional)',
          placeholder: 'Was ist passiert?',
          variant: CinemaInputVariant.multiline,
          maxLines: 4,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GlowButton(
                label: 'Abbrechen',
                variant: GlowVariant.ghost,
                fullWidth: true,
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlowButton(
                label: _submitting ? 'Sende...' : 'Melden',
                variant: GlowVariant.crisis,
                fullWidth: true,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────
String _relativeDate(String? iso) {
  if (iso == null) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final delta = DateTime.now().difference(t);
  if (delta.inDays >= 30) return '${(delta.inDays / 30).floor()} Mo';
  if (delta.inDays >= 1) return 'vor ${delta.inDays} T';
  if (delta.inHours >= 1) return 'vor ${delta.inHours} Std';
  if (delta.inMinutes >= 1) return 'vor ${delta.inMinutes} Min';
  return 'gerade eben';
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Angefragt';
    case 'accepted':
      return 'Angenommen';
    case 'completed':
      return 'Abgeschlossen';
    case 'cancelled':
      return 'Abgebrochen';
    default:
      return status;
  }
}
