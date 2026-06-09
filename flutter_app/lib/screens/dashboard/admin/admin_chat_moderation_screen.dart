import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/module_search_bar.dart';

/// SKILL: mensaena-features (Admin chat moderation)
/// Chat-Moderation: lock/unlock community chat, ban/unban senders,
/// soft-delete messages. Mirrors the web admin ChatModerationTab.
class AdminChatModerationScreen extends ConsumerStatefulWidget {
  const AdminChatModerationScreen({super.key});

  @override
  ConsumerState<AdminChatModerationScreen> createState() =>
      _AdminChatModerationScreenState();
}

class _AdminChatModerationScreenState
    extends ConsumerState<AdminChatModerationScreen> {
  Map<String, dynamic>? _communityRoom;
  List<Map<String, dynamic>> _messages = const [];
  List<Map<String, dynamic>> _chatUsers = const [];
  final TextEditingController _lockReasonCtrl = TextEditingController();
  final TextEditingController _msgSearchCtrl = TextEditingController();
  String _msgSearch = '';
  bool _loading = true;
  bool _isAdmin = false;
  bool _lockBusy = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadMyRole();
    _loadAll();
  }

  @override
  void dispose() {
    _lockReasonCtrl.dispose();
    _msgSearchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadMyRole() async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final row =
          await sb.from('profiles').select('role').eq('id', uid).maybeSingle();
      if (!mounted) return;
      setState(() => _isAdmin = row?['role'] == 'admin');
    } catch (_) {
      // ignore role lookup errors; default = not admin
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final room = await AdminRepository.getCommunityRoom();
      List<Map<String, dynamic>> messages = const [];
      final roomId = room?['id'] as String?;
      if (roomId != null) {
        messages = await AdminRepository.getChatMessages(roomId);
      }
      final bannedList = await AdminRepository.getChatBannedUsers();
      final bannedIds = bannedList
          .map((b) => b['user_id'] as String?)
          .whereType<String>()
          .toSet();
      // Extract unique users from messages
      final users = <String, Map<String, dynamic>>{};
      for (final m in messages) {
        final senderId = m['sender_id'] as String?;
        if (senderId == null || users.containsKey(senderId)) continue;
        final profile = m['profiles'] as Map<String, dynamic>?;
        users[senderId] = {
          'user_id': senderId,
          'name': profile?['name'] ?? 'Unbekannt',
          'email': profile?['email'] ?? '',
          'is_banned': bannedIds.contains(senderId),
        };
      }
      // Also include banned users that may have no messages
      for (final b in bannedList) {
        final uid = b['user_id'] as String?;
        if (uid == null || users.containsKey(uid)) continue;
        final profile = b['profiles'] as Map<String, dynamic>?;
        users[uid] = {
          'user_id': uid,
          'name': profile?['name'] ?? 'Unbekannt',
          'email': profile?['email'] ?? '',
          'is_banned': true,
        };
      }
      if (!mounted) return;
      setState(() {
        _communityRoom = room;
        _messages = messages;
        _chatUsers = users.values.toList();
        _lockReasonCtrl.text = (room?['locked_reason'] as String?) ?? '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearch(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _msgSearch = v);
    });
  }

  Future<void> _toggleLock() async {
    final room = _communityRoom;
    if (room == null) return;
    final roomId = room['id'] as String;
    final isLocked = room['is_locked'] == true;
    setState(() => _lockBusy = true);
    final ok = await AdminRepository.toggleChatLock(
      roomId,
      !isLocked,
      reason: !isLocked ? _lockReasonCtrl.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _lockBusy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          isLocked
              ? 'admin.chatMod.unlockSuccess'.tr()
              : 'admin.chatMod.lockSuccess'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
      _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'admin.chatMod.actionFailed'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    }
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    final uid = user['user_id'] as String;
    final wasBanned = user['is_banned'] == true;
    final ok = await AdminRepository.toggleChatBan(uid, wasBanned);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          wasBanned
              ? 'admin.chatMod.unbanSuccess'.tr()
              : 'admin.chatMod.banSuccess'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
      _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'admin.chatMod.actionFailed'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> msg) async {
    final mid = msg['id'] as String;
    final ok = await AdminRepository.softDeleteMessage(mid);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'admin.chatMod.deletedMsg'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
      _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          'admin.chatMod.actionFailed'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'admin.chatMod.title'.tr(),
      currentRoute: '/dashboard/admin/chat-moderation',
      onRefresh: _loadAll,
      body: SafeArea(
        child: _loading
            ? const _Skeleton()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _LockPanel(
                    room: _communityRoom,
                    lockReasonCtrl: _lockReasonCtrl,
                    isAdmin: _isAdmin,
                    busy: _lockBusy,
                    onToggle: _toggleLock,
                  ),
                  const SizedBox(height: 16),
                  _UsersPanel(
                    users: _chatUsers,
                    isAdmin: _isAdmin,
                    onToggleBan: _toggleBan,
                  ),
                  const SizedBox(height: 16),
                  _MessagesPanel(
                    messages: _messages,
                    search: _msgSearch,
                    msgSearchCtrl: _msgSearchCtrl,
                    isAdmin: _isAdmin,
                    onSearch: _onSearch,
                    onDelete: _deleteMessage,
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lock panel
// ---------------------------------------------------------------------------

class _LockPanel extends StatelessWidget {
  const _LockPanel({
    required this.room,
    required this.lockReasonCtrl,
    required this.isAdmin,
    required this.busy,
    required this.onToggle,
  });

  final Map<String, dynamic>? room;
  final TextEditingController lockReasonCtrl;
  final bool isAdmin;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isLocked = room?['is_locked'] == true;
    final lockedReason = room?['locked_reason'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.messageCircle,
                  size: 20, color: AppColors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'admin.chatMod.communityChat'.tr(),
                  style: AppTypography.display(size: 16, color: AppColors.ink),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isLocked ? AppColors.herzrot : AppColors.leben)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isLocked
                      ? 'admin.chatMod.locked'.tr()
                      : 'admin.chatMod.open'.tr(),
                  style: AppTypography.label(
                    size: 9,
                    color: isLocked ? AppColors.herzrot : AppColors.leben,
                  ),
                ),
              ),
            ],
          ),
          if (isLocked && lockedReason != null && lockedReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.herzrot.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                lockedReason,
                style:
                    AppTypography.body(size: 13, color: AppColors.inkSoft),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!isLocked)
            TextField(
              controller: lockReasonCtrl,
              maxLength: 200,
              enabled: isAdmin && !busy,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'admin.chatMod.reasonLabel'.tr(),
                labelStyle:
                    AppTypography.body(size: 12, color: AppColors.mute),
                filled: true,
                fillColor: AppColors.elevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.amber, width: 1.2),
                ),
                counterStyle: AppTypography.caption(),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: (!isAdmin || busy || room == null) ? null : onToggle,
              icon: Icon(
                isLocked ? LucideIcons.unlock : LucideIcons.lock,
                size: 16,
              ),
              label: Text(
                isLocked
                    ? 'admin.chatMod.unlock'.tr()
                    : 'admin.chatMod.lock'.tr(),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    isLocked ? AppColors.leben : AppColors.herzrot,
                foregroundColor: AppColors.voidColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (!isAdmin) ...[
            const SizedBox(height: 8),
            Text(
              'admin.chatMod.adminOnly'.tr(),
              style: AppTypography.caption(),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Users panel
// ---------------------------------------------------------------------------

class _UsersPanel extends StatelessWidget {
  const _UsersPanel({
    required this.users,
    required this.isAdmin,
    required this.onToggleBan,
  });

  final List<Map<String, dynamic>> users;
  final bool isAdmin;
  final ValueChanged<Map<String, dynamic>> onToggleBan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'admin.chatMod.usersTitle'
                      .tr(namedArgs: {'n': '${users.length}'}),
                  style: AppTypography.display(size: 16, color: AppColors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'admin.chatMod.noUsers'.tr(),
                  style: AppTypography.body(size: 13, color: AppColors.mute),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: users.length,
                itemBuilder: (ctx, i) => _UserModRow(
                  user: users[i],
                  isAdmin: isAdmin,
                  onToggleBan: onToggleBan,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserModRow extends StatelessWidget {
  const _UserModRow({
    required this.user,
    required this.isAdmin,
    required this.onToggleBan,
  });

  final Map<String, dynamic> user;
  final bool isAdmin;
  final ValueChanged<Map<String, dynamic>> onToggleBan;

  @override
  Widget build(BuildContext context) {
    final isBanned = user['is_banned'] == true;
    final name = (user['name'] as String?)?.trim();
    final email = (user['email'] as String?) ?? '';
    final initial = (name != null && name.isNotEmpty)
        ? name.characters.first.toUpperCase()
        : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBanned
            ? AppColors.herzrot.withValues(alpha: 0.06)
            : AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBanned
              ? AppColors.herzrot.withValues(alpha: 0.5)
              : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.raised,
            child: Text(
              initial,
              style: AppTypography.label(size: 12, color: AppColors.inkSoft),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name?.isNotEmpty == true ? name! : '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isBanned) ...[
                      const SizedBox(width: 6),
                      _MicroBadge(
                        color: AppColors.herzrot,
                        label: 'admin.chatMod.bannedBadge'.tr(),
                      ),
                    ],
                  ],
                ),
                if (email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(),
                    ),
                  ),
              ],
            ),
          ),
          if (isAdmin)
            TextButton(
              onPressed: () => onToggleBan(user),
              style: TextButton.styleFrom(
                foregroundColor:
                    isBanned ? AppColors.leben : AppColors.herzrot,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                isBanned
                    ? 'admin.chatMod.unban'.tr()
                    : 'admin.chatMod.ban'.tr(),
                style: AppTypography.label(
                  size: 11,
                  color: isBanned ? AppColors.leben : AppColors.herzrot,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages panel
// ---------------------------------------------------------------------------

class _MessagesPanel extends StatelessWidget {
  const _MessagesPanel({
    required this.messages,
    required this.search,
    required this.msgSearchCtrl,
    required this.isAdmin,
    required this.onSearch,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> messages;
  final String search;
  final TextEditingController msgSearchCtrl;
  final bool isAdmin;
  final ValueChanged<String> onSearch;
  final ValueChanged<Map<String, dynamic>> onDelete;

  List<Map<String, dynamic>> _filter() {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return messages;
    return messages.where((m) {
      final c = (m['content'] as String? ?? '').toLowerCase();
      return c.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'admin.chatMod.messagesTitle'
                      .tr(namedArgs: {'n': '${messages.length}'}),
                  style: AppTypography.display(size: 16, color: AppColors.ink),
                ),
              ),
              SizedBox(
                width: 180,
                child: ModuleSearchBar(
                  hintText: 'common.search'.tr(),
                  initialValue: msgSearchCtrl.text,
                  onChanged: onSearch,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'admin.chatMod.noMessages'.tr(),
                  style: AppTypography.body(size: 13, color: AppColors.mute),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 500),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _MessageModRow(
                  msg: filtered[i],
                  isAdmin: isAdmin,
                  onDelete: onDelete,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageModRow extends StatelessWidget {
  const _MessageModRow({
    required this.msg,
    required this.isAdmin,
    required this.onDelete,
  });

  final Map<String, dynamic> msg;
  final bool isAdmin;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    final isDeleted = msg['deleted_at'] != null;
    final content = (msg['content'] as String?) ?? '';
    final profile = msg['profiles'] as Map<String, dynamic>?;
    final senderName = (profile?['name'] as String?)?.trim();
    final createdAt = DateTime.tryParse(msg['created_at'] as String? ?? '')?.toUtc();
    return Opacity(
      opacity: isDeleted ? 0.5 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          senderName?.isNotEmpty == true ? senderName! : '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (createdAt != null)
                        Text(
                          DateFormat('dd.MM. HH:mm').format(createdAt),
                          style: AppTypography.caption(),
                        ),
                      if (isDeleted) ...[
                        const SizedBox(width: 6),
                        _MicroBadge(
                          color: AppColors.mute,
                          label: 'admin.chatMod.deletedBadge'.tr(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isDeleted
                        ? 'admin.chatMod.deletedMsgPlaceholder'.tr()
                        : content,
                    style: AppTypography.body(
                      size: 13,
                      color: isDeleted ? AppColors.mute : AppColors.inkSoft,
                    ).copyWith(
                      fontStyle:
                          isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (!isDeleted && isAdmin)
              IconButton(
                onPressed: () => onDelete(msg),
                icon: const Icon(LucideIcons.trash2,
                    color: AppColors.herzrot, size: 18),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'common.delete'.tr(),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _MicroBadge extends StatelessWidget {
  const _MicroBadge({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.label(size: 8, color: color),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: const [
        ShimmerBox(height: 180, borderRadius: 12),
        SizedBox(height: 16),
        ShimmerBox(height: 240, borderRadius: 12),
        SizedBox(height: 16),
        ShimmerBox(height: 340, borderRadius: 12),
      ],
    );
  }
}
