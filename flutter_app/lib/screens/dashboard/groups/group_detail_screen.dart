import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/groups_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/parallax_image_header.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/premium_image.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/error_state_widget.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.groupId, super.key});
  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  final _postCtrl = TextEditingController();
  final _scroll = ScrollController();
  // PERF/BUG (Audit): vorher konnte der Send-Button durch schnelle Doppel-
  // Taps zwei identische Posts in die Gruppe schicken (Submit war nicht
  // gegen In-Flight-Aufrufe geschützt). Flag verhindert das.
  bool _sending = false;

  @override
  void dispose() {
    _postCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final text = _postCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await GroupsRepository.addPost(
      groupId: widget.groupId,
      content: text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) return;
    _postCtrl.clear();
    ref.invalidate(groupPostsProvider(widget.groupId));
  }

  /// G3: Beitritts-Antrag mit optionaler Nachricht (Eisbrecher-Frage).
  Future<void> _requestJoin(String groupId) async {
    final ctrl = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('groups.requestJoinTitle'.tr(),
            style: AppTypography.display(size: 16, color: AppColors.ink)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 280,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'groups.requestJoinHint'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('groups.requestSend'.tr()),
          ),
        ],
      ),
    );
    if (send != true) return;
    final ok = await GroupsRepository.requestJoin(groupId, ctrl.text);
    if (!mounted) return;
    if (ok) {
      ref.invalidate(groupMyJoinStatusProvider(groupId));
      AppSnackBar.success(context, 'groups.requestSent'.tr());
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: Text('groups.deletePostConfirm'.tr(),
            style: AppTypography.body(size: 14, color: AppColors.ink)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.herzrot),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final ok = await GroupsRepository.deletePost(postId);
    if (!mounted) return;
    if (ok) ref.invalidate(groupPostsProvider(widget.groupId));
  }

  /// G1: Event-Erstellen-Dialog (Titel, Ort, Datum/Uhrzeit, Beschreibung).
  Future<void> _createEvent(String groupId) async {
    final titleCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime when = DateTime.now().add(const Duration(days: 1, hours: 1));
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dlg) => StatefulBuilder(
        builder: (dlg, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('groups.createEventLong'.tr(),
              style: AppTypography.display(size: 18, color: AppColors.ink)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  maxLength: 120,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'groups.eventTitle'.tr(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: locCtrl,
                  maxLength: 160,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'groups.eventWhere'.tr(),
                    prefixIcon: const Icon(LucideIcons.mapPin,
                        size: 16, color: AppColors.mute),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: dlg,
                      initialDate: when,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d == null) return;
                    if (!dlg.mounted) return;
                    final t = await showTimePicker(
                      context: dlg,
                      initialTime: TimeOfDay.fromDateTime(when),
                    );
                    if (t == null) return;
                    setLocal(() => when = DateTime(
                        d.year, d.month, d.day, t.hour, t.minute));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calendar,
                            size: 16, color: AppColors.amber),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEE, dd.MM.yyyy · HH:mm')
                              .format(when),
                          style: AppTypography.body(
                              size: 14, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: 'groups.eventDescription'.tr(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(dlg),
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
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      setLocal(() => sending = true);
                      final ok = await GroupsRepository.createGroupEvent(
                        groupId: groupId,
                        title: title,
                        description: descCtrl.text,
                        location: locCtrl.text,
                        startAt: when,
                      );
                      if (!dlg.mounted) return;
                      Navigator.pop(dlg);
                      if (ok) {
                        ref.invalidate(groupEventsProvider(groupId));
                      }
                    },
              child: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.voidColor),
                    )
                  : Text('groups.eventSave'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailProvider(widget.groupId));
    final isMember = ref.watch(groupMembershipProvider(widget.groupId));
    final posts = ref.watch(groupPostsProvider(widget.groupId));
    // G2: Owner/Admin der Gruppe dürfen fremde Posts moderieren.
    final myRole = ref.watch(groupMyRoleProvider(widget.groupId)).value;
    final canModerate = myRole == 'owner' || myRole == 'admin';
    final myUid = SupabaseService.currentUser?.id;
    // G3: Beitritts-Antrag-Status (für private Gruppen).
    final joinStatus =
        ref.watch(groupMyJoinStatusProvider(widget.groupId)).value;

    return DashboardScaffold(
      title: 'groups.title'.tr(),
      currentRoute: '/dashboard/groups',
      onRefresh: () async {
        ref.invalidate(groupDetailProvider(widget.groupId));
        ref.invalidate(groupPostsProvider(widget.groupId));
        ref.invalidate(groupMembershipProvider(widget.groupId));
        ref.invalidate(groupMyRoleProvider(widget.groupId));
        ref.invalidate(groupMyJoinStatusProvider(widget.groupId));
      },
      body: SafeArea(
        child: group.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) => Center(
            child: ErrorStateWidget(
              onRetry: () =>
                  ref.invalidate(groupDetailProvider(widget.groupId)),
            ),
          ),
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
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (g.bannerUrl != null)
                        ParallaxImageHeader(
                          scrollController: _scroll,
                          height: 140,
                          child: PremiumImage(
                            url: g.bannerUrl,
                            height: 140,
                            width: double.infinity,
                            borderRadius: BorderRadius.circular(14),
                            bottomGradient: true,
                            heroTag: 'group_banner_${g.id}',
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
                          // G3: private Gruppe → Antrag stellen statt
                          // direktem Beitritt.
                          else if (g.isPrivate && joinStatus == 'pending')
                            Chip(
                              backgroundColor:
                                  AppColors.amber.withValues(alpha: 0.16),
                              label: Text('groups.requestPending'.tr(),
                                  style: AppTypography.label(
                                      size: 10, color: AppColors.amber)),
                            )
                          else if (g.isPrivate)
                            ElevatedButton.icon(
                              onPressed: () => _requestJoin(g.id),
                              icon: const Icon(LucideIcons.lock, size: 14),
                              label: Text('groups.requestJoin'.tr()),
                            )
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
                      // G3: Owner/Admin-Anträge-Panel.
                      if (canModerate)
                        _PendingRequestsPanel(groupId: widget.groupId),
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
                      // G1: Gruppen-Events — nur für Mitglieder sichtbar.
                      if (isMember.asData?.value == true) ...[
                        const SizedBox(height: 20),
                        _GroupEventsSection(
                          groupId: widget.groupId,
                          canModerate: canModerate,
                          myUid: myUid,
                          onCreate: () => _createEvent(widget.groupId),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text('groups.posts'.tr(),
                          style: AppTypography.label(size: 10)),
                      const SizedBox(height: 8),
                      posts.when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => ErrorStateWidget(
                          compact: true,
                          onRetry: () => ref
                              .invalidate(groupPostsProvider(widget.groupId)),
                        ),
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
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (p.isPinned)
                                          const Padding(
                                            padding:
                                                EdgeInsets.only(right: 6),
                                            child: Icon(LucideIcons.pin,
                                                size: 12,
                                                color: AppColors.amber),
                                          ),
                                        Expanded(
                                          child: Text(
                                            p.content,
                                            style: AppTypography.body(
                                              size: 13,
                                              color: AppColors.ink,
                                              height: 1.45,
                                            ),
                                          ),
                                        ),
                                        if (canModerate || p.userId == myUid)
                                          GestureDetector(
                                            onTap: () =>
                                                _deletePost(p.id),
                                            child: const Padding(
                                              padding:
                                                  EdgeInsets.only(left: 6),
                                              child: Icon(
                                                LucideIcons.trash2,
                                                size: 14,
                                                color: AppColors.mute,
                                              ),
                                            ),
                                          ),
                                      ],
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
                          tooltip: 'common.send'.tr(),
                          onPressed: _sending ? null : _submit,
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.amber),
                                )
                              : const Icon(LucideIcons.send,
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
    final url = 'https://www.mensaena.de/get/groups/$id';
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

/// G1: Sektion mit kommenden Gruppen-Events (nur für Mitglieder). Mitglieder
/// können neue Events anlegen; Ersteller bzw. Owner/Admin dürfen löschen.
class _GroupEventsSection extends ConsumerWidget {
  const _GroupEventsSection({
    required this.groupId,
    required this.canModerate,
    required this.myUid,
    required this.onCreate,
  });
  final String groupId;
  final bool canModerate;
  final String? myUid;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupEventsProvider(groupId));
    final events = async.asData?.value ?? const [];

    Future<void> delete(String id) async {
      final ok = await GroupsRepository.deleteGroupEvent(id);
      if (ok) ref.invalidate(groupEventsProvider(groupId));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('groups.eventsTitle'.tr(),
                style: AppTypography.label(size: 10)),
            const Spacer(),
            TextButton.icon(
              onPressed: onCreate,
              icon: const Icon(LucideIcons.calendarPlus,
                  size: 14, color: AppColors.amber),
              label: Text('groups.createEvent'.tr(),
                  style: AppTypography.label(size: 10, color: AppColors.amber)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Text('groups.noEvents'.tr(), style: AppTypography.caption())
        else
          for (final e in events)
            Builder(builder: (_) {
              final id = e['id'] as String;
              final title = (e['title'] ?? '').toString();
              final loc = (e['location'] ?? '').toString();
              final desc = (e['description'] ?? '').toString();
              final startStr = e['start_at']?.toString();
              final start = startStr != null
                  ? DateTime.tryParse(startStr)?.toUtc()
                  : null;
              final canDelete =
                  canModerate || e['created_by'] == myUid;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.06),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            start != null
                                ? DateFormat('dd').format(start)
                                : '–',
                            style: AppTypography.display(
                                size: 18, color: AppColors.amber),
                          ),
                          Text(
                            start != null
                                ? DateFormat('MMM').format(start)
                                : '',
                            style: AppTypography.label(
                                size: 9, color: AppColors.amber),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.ink,
                                  weight: FontWeight.w700)),
                          if (start != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.clock,
                                      size: 11, color: AppColors.mute),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('EEE, HH:mm').format(start),
                                    style: AppTypography.caption(),
                                  ),
                                ],
                              ),
                            ),
                          if (loc.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.mapPin,
                                      size: 11, color: AppColors.mute),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(loc,
                                        style: AppTypography.caption(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ),
                          if (desc.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(desc,
                                  style: AppTypography.body(
                                      size: 12, color: AppColors.inkSoft),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                      ),
                    ),
                    if (canDelete)
                      GestureDetector(
                        onTap: () => delete(id),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(LucideIcons.trash2,
                              size: 14, color: AppColors.mute),
                        ),
                      ),
                  ],
                ),
              );
            }),
      ],
    );
  }
}

/// G3: Panel mit offenen Beitritts-Anträgen für Owner/Admin. Jeder Antrag
/// zeigt Antragsteller + Nachricht + Annehmen/Ablehnen.
class _PendingRequestsPanel extends ConsumerWidget {
  const _PendingRequestsPanel({required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(groupPendingRequestsProvider(groupId));
    final reqs = async.asData?.value ?? const [];
    if (reqs.isEmpty) return const SizedBox.shrink();

    Future<void> decide(String id, bool approve) async {
      final ok = approve
          ? await GroupsRepository.approveRequest(id)
          : await GroupsRepository.rejectRequest(id);
      if (ok) {
        ref.invalidate(groupPendingRequestsProvider(groupId));
        ref.invalidate(groupDetailProvider(groupId));
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'groups.requestsCount'.tr(namedArgs: {'n': '${reqs.length}'}),
            style: AppTypography.label(size: 10, color: AppColors.bronze),
          ),
          const SizedBox(height: 8),
          for (final r in reqs) ...[
            Builder(builder: (_) {
              final p = r['profiles'] as Map<String, dynamic>?;
              final name = (p?['display_name'] ??
                      p?['name'] ??
                      'common.neighbour'.tr())
                  .toString();
              final msg = (r['message'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                    if (msg.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('„$msg"',
                            style: AppTypography.body(
                                size: 12, color: AppColors.inkSoft)),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              decide(r['id'] as String, true),
                          icon: const Icon(LucideIcons.check, size: 13),
                          label: Text('groups.requestApprove'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.leben,
                            side: BorderSide(
                                color: AppColors.leben
                                    .withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              decide(r['id'] as String, false),
                          icon: const Icon(LucideIcons.x, size: 13),
                          label: Text('groups.requestReject'.tr()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mute,
                            side: const BorderSide(color: AppColors.line),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
