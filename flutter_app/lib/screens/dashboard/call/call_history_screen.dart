/// SKILL: mensaena-features
/// Anrufhistorie — letzte 30 DM-Anrufe mit Richtung, Dauer und Status.
///
/// Pendant zu Web `CallHistory.tsx`. Joint dm_calls mit profiles fuer
/// Caller/Callee Namen + Avatare. Tap auf eine Zeile → neuer Anruf an
/// dieselbe Person.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/dm_call_service.dart';
import '../../../services/haptics.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/sized_avatar_image.dart';
import '../../../widgets/shared/skeleton_card.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final myId = SupabaseService.currentUser?.id;
    if (myId == null) {
      _future = Future.value(const <Map<String, dynamic>>[]);
      return;
    }
    _future = _fetch(myId);
  }

  Future<List<Map<String, dynamic>>> _fetch(String myId) async {
    try {
      final rows = await sb
          .from('dm_calls')
          .select('id, caller_id, callee_id, call_type, status, '
              'created_at, answered_at, ended_at, conversation_id, room_name, '
              'caller_hidden_at, callee_hidden_at, '
              'caller:profiles!dm_calls_caller_id_fkey(id,display_name,name,avatar_url),'
              'callee:profiles!dm_calls_callee_id_fkey(id,display_name,name,avatar_url)')
          .or('and(caller_id.eq.$myId,caller_hidden_at.is.null),and(callee_id.eq.$myId,callee_hidden_at.is.null)')
          .order('created_at', ascending: false)
          .limit(30);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      // Fallback ohne Joins — manche Supabase-Setups erlauben den Embed nicht.
      try {
        final rows = await sb
            .from('dm_calls')
            .select()
            .or('and(caller_id.eq.$myId,caller_hidden_at.is.null),and(callee_id.eq.$myId,callee_hidden_at.is.null)')
            .order('created_at', ascending: false)
            .limit(30);
        return List<Map<String, dynamic>>.from(rows as List);
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
  }

  Future<void> _hideOne(String callId) async {
    final ok = await DmCallService.hideCallForMe(callId);
    if (!mounted) return;
    if (ok) {
      setState(_load);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('common.failed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm)),
      ));
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('callHistory.clearAllTitle'.tr(),
            style: AppTypography.body(
                size: 15, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text('callHistory.clearAllBody'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final count = await DmCallService.hideAllCallsForMe();
    if (!mounted) return;
    if (count != null) {
      setState(_load);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('callHistory.cleared'.tr(namedArgs: {'n': '$count'}),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('common.failed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.herzrotWarm)),
      ));
    }
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'callHistory.title'.tr(),
      currentRoute: '/dashboard/call-history',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SkeletonList(count: 6, itemHeight: 76);
              }
              final list = snap.data ?? const <Map<String, dynamic>>[];
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 80),
                    EmptyStateCard(
                      icon: LucideIcons.phoneOff,
                      title: 'callHistory.emptyTitle'.tr(),
                      description: 'callHistory.emptyDescription'.tr(),
                    ),
                  ],
                );
              }
              final myId = SupabaseService.currentUser?.id;
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: list.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(LucideIcons.trash2,
                            size: 14, color: AppColors.herzrotWarm),
                        label: Text(
                          'callHistory.clearAll'.tr(),
                          style: AppTypography.body(
                              size: 12,
                              color: AppColors.herzrotWarm,
                              weight: FontWeight.w600),
                        ),
                      ),
                    );
                  }
                  final row = list[i - 1];
                  final id = row['id'] as String;
                  return Dismissible(
                    key: ValueKey('call-$id'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.herzrot.withValues(alpha: 0.18),
                        border: Border.all(
                            color: AppColors.herzrot.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.trash2,
                          color: AppColors.herzrot, size: 20),
                    ),
                    onDismissed: (_) => _hideOne(id),
                    child: _CallRow(row: row, myId: myId ?? ''),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({required this.row, required this.myId});

  final Map<String, dynamic> row;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final callerId = row['caller_id'] as String?;
    final isOutgoing = callerId == myId;
    final peer = isOutgoing
        ? (row['callee'] as Map<String, dynamic>?)
        : (row['caller'] as Map<String, dynamic>?);
    final peerId = isOutgoing
        ? row['callee_id'] as String?
        : row['caller_id'] as String?;
    final peerName = (peer?['display_name'] as String?) ??
        (peer?['name'] as String?) ??
        'callHistory.unknownPeer'.tr();
    final avatarUrl = peer?['avatar_url'] as String?;
    final status = (row['status'] as String?) ?? 'ended';
    final callType = (row['call_type'] as String?) ?? 'audio';
    final created = DateTime.tryParse(row['created_at'] as String? ?? '');
    final answered = DateTime.tryParse(row['answered_at'] as String? ?? '');
    final ended = DateTime.tryParse(row['ended_at'] as String? ?? '');

    final dirInfo = _directionInfo(isOutgoing, status);
    final durationText = _durationText(status, answered, ended);
    final relTime = _relativeTime(created);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: peerId == null
          ? null
          : () => _callBack(
                context: context,
                peerId: peerId,
                peerName: peerName,
                conversationId: row['conversation_id'] as String?,
                callType: callType,
              ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedAvatarImage(
              url: avatarUrl,
              size: 52,
              fallbackInitial: peerName.isNotEmpty
                  ? peerName[0].toUpperCase()
                  : '?',
              borderRadius: BorderRadius.circular(26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(dirInfo.icon, size: 12, color: dirInfo.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          durationText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(
                            size: 10,
                            color: dirInfo.color,
                          ),
                        ),
                      ),
                      if (callType == 'video') ...[
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.video,
                            size: 11, color: AppColors.mute),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              relTime,
              style: AppTypography.label(size: 10, color: AppColors.mute),
            ),
          ],
        ),
      ),
    );
  }

  static _DirInfo _directionInfo(bool isOutgoing, String status) {
    if (status == 'missed') {
      return const _DirInfo(
        icon: LucideIcons.phoneMissed,
        color: AppColors.herzrot,
      );
    }
    if (isOutgoing) {
      return const _DirInfo(
        icon: LucideIcons.phoneOutgoing,
        color: AppColors.bronze,
      );
    }
    return const _DirInfo(
      icon: LucideIcons.phoneIncoming,
      color: AppColors.lebenSoft,
    );
  }

  static String _durationText(
      String status, DateTime? answered, DateTime? ended) {
    if (status == 'missed') return 'callHistory.statusMissed'.tr();
    if (status == 'cancelled') return 'callHistory.statusCancelled'.tr();
    if (status == 'ringing') return 'callHistory.statusRinging'.tr();
    if (answered != null && ended != null && ended.isAfter(answered)) {
      final dur = ended.difference(answered);
      final m = dur.inMinutes.toString().padLeft(2, '0');
      final s = (dur.inSeconds % 60).toString().padLeft(2, '0');
      return '$m:$s';
    }
    return 'callHistory.statusEnded'.tr();
  }

  static String _relativeTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'time.justNow'.tr();
    if (diff.inMinutes < 60) {
      return 'time.minutesShort'
          .tr(namedArgs: {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'time.hoursShort'.tr(namedArgs: {'n': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return 'time.daysShort'.tr(namedArgs: {'n': '${diff.inDays}'});
    }
    return DateFormat.yMMMd().format(t.toLocal());
  }

  Future<void> _callBack({
    required BuildContext context,
    required String peerId,
    required String peerName,
    required String? conversationId,
    required String callType,
  }) async {
    Haptics.tap();
    if (conversationId == null || conversationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('callHistory.callbackNoConv'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      return;
    }
    final result = await DmCallService.start(
      conversationId: conversationId,
      calleeId: peerId,
      callType: callType,
    );
    if (!context.mounted) return;
    if (!result.success || result.callId == null || result.roomName == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
            result.errorReason ?? 'callHistory.callbackFailed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      return;
    }
    final encPeer = Uri.encodeComponent(peerName);
    final encRoom = Uri.encodeComponent(result.roomName!);
    context.push(
        '/dashboard/call/${result.callId}?room=$encRoom&peer=$encPeer');
  }
}

class _DirInfo {
  const _DirInfo({required this.icon, required this.color});
  final IconData icon;
  final Color color;
}
