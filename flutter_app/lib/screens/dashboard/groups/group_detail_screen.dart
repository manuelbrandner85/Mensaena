import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/groups_repository.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.groupId, super.key});
  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _postCtrl = TextEditingController();

  @override
  void dispose() {
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty) return;
    final ok = await GroupsRepository.addPost(
      groupId: widget.groupId,
      content: text,
    );
    if (!ok || !mounted) return;
    _postCtrl.clear();
    ref.invalidate(groupPostsProvider(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailProvider(widget.groupId));
    final isMember = ref.watch(groupMembershipProvider(widget.groupId));
    final posts = ref.watch(groupPostsProvider(widget.groupId));

    return DashboardScaffold(
      title: 'groups.title'.tr(),
      currentRoute: '/dashboard/groups',
      body: SafeArea(
        child: group.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) =>
              Center(child: Text('$e', style: AppTypography.caption())),
          data: (g) {
            if (g == null) {
              return Center(
                child: Text('groups.notFound'.tr(),
                    style: AppTypography.caption()),
              );
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (g.bannerUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            imageUrl: g.bannerUrl!,
                            fadeInDuration:
                                const Duration(milliseconds: 200),
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const ShimmerBox(
                              width: double.infinity,
                              height: 140,
                              borderRadius: 14,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.elevated,
                              height: 140,
                              alignment: Alignment.center,
                              child: const Icon(LucideIcons.imageOff,
                                  size: 20, color: AppColors.mute),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (g.avatarUrl != null)
                            CachedNetworkImage(
                              imageUrl: g.avatarUrl!,
                              fadeInDuration:
                                  const Duration(milliseconds: 200),
                              imageBuilder: (_, img) => CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.elevated,
                                backgroundImage: img,
                              ),
                              placeholder: (_, __) => const CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.elevated,
                              ),
                              errorWidget: (_, __, ___) => const CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.elevated,
                                child: Icon(LucideIcons.users2,
                                    color: AppColors.amber),
                              ),
                            )
                          else
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.elevated,
                              child: Icon(LucideIcons.users2,
                                  color: AppColors.amber),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  style: AppTypography.display(
                                    size: 22,
                                    color: AppColors.ink,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(g.category,
                                        style: AppTypography.label(size: 10)),
                                    const SizedBox(width: 8),
                                    const Icon(LucideIcons.users,
                                        size: 12, color: AppColors.mute),
                                    const SizedBox(width: 4),
                                    Text(
                                        g.maxMembers != null &&
                                                g.maxMembers! > 0
                                            ? '${g.memberCount}/${g.maxMembers}'
                                            : 'groups.memberCount'.tr(
                                                namedArgs: {
                                                    'count': '${g.memberCount}'
                                                  }),
                                        style: AppTypography.caption()),
                                    if (g.latitude != null &&
                                        (g.radiusKm ?? 0) > 0) ...[
                                      const SizedBox(width: 8),
                                      const Icon(LucideIcons.mapPin,
                                          size: 12, color: AppColors.mute),
                                      const SizedBox(width: 4),
                                      Text('${g.radiusKm} km',
                                          style: AppTypography.caption()),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _shareGroup(g.id, g.name),
                            tooltip: 'common.share'.tr(),
                            icon: const Icon(LucideIcons.share2,
                                size: 18, color: AppColors.amber),
                          ),
                          if (isMember.asData?.value == true) ...[
                            IconButton(
                              onPressed: () => _openInviteDialog(context, g.id),
                              tooltip: 'groups.inviteMember'.tr(),
                              icon: const Icon(LucideIcons.userPlus,
                                  size: 18, color: AppColors.amber),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final m = ScaffoldMessenger.of(context);
                                await GroupsRepository.leave(g.id);
                                ref.invalidate(
                                    groupMembershipProvider(g.id));
                                ref.invalidate(groupDetailProvider(g.id));
                                m.showSnackBar(SnackBar(
                                  backgroundColor: AppColors.surface,
                                  content: Text('groups.leftSnack'.tr(),
                                      style: AppTypography.body(
                                          size: 13, color: AppColors.ink)),
                                ));
                              },
                              icon: const Icon(LucideIcons.logOut, size: 14),
                              label: Text('groups.leave'.tr()),
                            ),
                          ]
                          else
                            ElevatedButton.icon(
                              onPressed: () async {
                                final m = ScaffoldMessenger.of(context);
                                await GroupsRepository.join(g.id);
                                ref.invalidate(
                                    groupMembershipProvider(g.id));
                                ref.invalidate(groupDetailProvider(g.id));
                                m.showSnackBar(SnackBar(
                                  backgroundColor: AppColors.surface,
                                  content: Text('groups.joinedSnack'.tr(),
                                      style: AppTypography.body(
                                          size: 13, color: AppColors.ink)),
                                ));
                              },
                              icon: const Icon(LucideIcons.plus, size: 14),
                              label: Text('groups.join'.tr()),
                            ),
                        ],
                      ),
                      if (g.description != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          g.description!,
                          style: AppTypography.body(
                            size: 14,
                            color: AppColors.inkSoft,
                            height: 1.55,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text('groups.posts'.tr(),
                          style: AppTypography.label(size: 10)),
                      const SizedBox(height: 8),
                      posts.when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) =>
                            Text('$e', style: AppTypography.caption()),
                        data: (list) {
                          if (list.isEmpty) {
                            return Text(
                              'groups.noPostsYet'.tr(),
                              style: AppTypography.caption(),
                            );
                          }
                          return Column(
                            children: list.map((p) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.surface.withValues(alpha: 0.4),
                                  border: Border.all(color: AppColors.line),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (p.isPinned)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 4),
                                        child: Icon(LucideIcons.pin,
                                            size: 12, color: AppColors.amber),
                                      ),
                                    Text(
                                      p.content,
                                      style: AppTypography.body(
                                        size: 13,
                                        color: AppColors.ink,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (p.createdAt != null)
                                      Text(
                                        DateFormat('dd.MM. HH:mm')
                                            .format(p.createdAt!),
                                        style: AppTypography.caption(),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (isMember.asData?.value == true)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.deep,
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _postCtrl,
                            maxLines: null,
                            style: AppTypography.body(
                                size: 14, color: AppColors.ink),
                            decoration: InputDecoration(
                              hintText: 'groups.writePost'.tr(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _submit,
                          icon: const Icon(LucideIcons.send,
                              color: AppColors.amber),
                        ),
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

  /// Deep-Link Share auf www.mensaena.de/dashboard/groups/{id}.
  Future<void> _shareGroup(String id, String name) async {
    final url = 'https://www.mensaena.de/dashboard/groups/$id';
    await Share.share(
      'groups.shareBody'.tr(namedArgs: {'title': name, 'url': url}),
      subject: 'groups.shareSubject'.tr(namedArgs: {'title': name}),
    );
  }

  Future<void> _openInviteDialog(BuildContext ctx, String groupId) async {
    final emailCtrl = TextEditingController();
    bool sending = false;
    await showDialog<void>(
      context: ctx,
      builder: (dlg) => StatefulBuilder(
        builder: (dlg, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('groups.inviteMember'.tr(),
              style:
                  AppTypography.display(size: 18, color: AppColors.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'groups.inviteEmailHint'.tr(),
                style: AppTypography.caption(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'groups.inviteEmailPlaceholder'.tr(),
                  prefixIcon: const Icon(LucideIcons.mail,
                      size: 16, color: AppColors.mute),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  sending ? null : () => Navigator.pop(dlg),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.voidColor,
              ),
              onPressed: sending
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) return;
                      setLocal(() => sending = true);
                      final ok = await GroupsRepository.inviteByEmail(
                          groupId, email);
                      if (!dlg.mounted) return;
                      Navigator.pop(dlg);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surface,
                          content: Text(
                            ok
                                ? 'groups.inviteSentTo'.tr(namedArgs: {'email': email})
                                : 'groups.inviteFailed'.tr(),
                            style: AppTypography.body(
                                size: 13, color: AppColors.ink),
                          ),
                        ),
                      );
                    },
              child: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.voidColor,
                      ),
                    )
                  : Text('groups.inviteSend'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
