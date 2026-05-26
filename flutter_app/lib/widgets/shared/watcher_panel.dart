/// SKILL: mensaena-features + mensaena-design
/// Side-Panel: Liste aller aktuellen Stream-Zuschauer mit Avataren.
/// Plus Top-Toast wenn jemand joint/leaves.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class WatcherEntry {
  const WatcherEntry({
    required this.identity,
    required this.name,
    this.avatarUrl,
  });
  final String identity;
  final String name;
  final String? avatarUrl;
}

class WatcherPanel extends StatelessWidget {
  const WatcherPanel({
    required this.watchers,
    required this.onClose,
    super.key,
  });

  final List<WatcherEntry> watchers;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.75,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.deep.withValues(alpha: 0.95),
          border: const Border(
              left: BorderSide(color: AppColors.line, width: 1)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(LucideIcons.users,
                        size: 16, color: AppColors.bronze),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'watchers.title'.tr(
                            namedArgs: {'n': '${watchers.length}'}),
                        style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(LucideIcons.x,
                          size: 18, color: AppColors.mute),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.line, height: 1),
              Expanded(
                child: watchers.isEmpty
                    ? Center(
                        child: Text('watchers.empty'.tr(),
                            style: AppTypography.caption()),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: watchers.length,
                        separatorBuilder: (_, __) => const Divider(
                            color: AppColors.line, height: 1),
                        itemBuilder: (_, i) {
                          final w = watchers[i];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.surface,
                              backgroundImage:
                                  w.avatarUrl != null
                                      ? CachedNetworkImageProvider(
                                          w.avatarUrl!)
                                      : null,
                              child: w.avatarUrl == null
                                  ? Text(
                                      w.name.isNotEmpty
                                          ? w.name[0].toUpperCase()
                                          : '?',
                                      style: AppTypography.body(
                                          size: 14,
                                          color: AppColors.bronze,
                                          weight: FontWeight.w700))
                                  : null,
                            ),
                            title: Text(
                              w.name,
                              style: AppTypography.body(
                                  size: 13, color: AppColors.ink),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slide-In Toast oben — "X ist beigetreten" / "X ist gegangen".
class JoinLeaveToast extends StatelessWidget {
  const JoinLeaveToast({
    required this.name,
    required this.kind,
    super.key,
  });

  final String name;
  final JoinLeaveKind kind;

  @override
  Widget build(BuildContext context) {
    final isJoin = kind == JoinLeaveKind.join;
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isJoin ? AppColors.leben : AppColors.mute)
            .withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isJoin ? LucideIcons.logIn : LucideIcons.logOut,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            isJoin
                ? 'watchers.joined'.tr(namedArgs: {'name': name})
                : 'watchers.left'.tr(namedArgs: {'name': name}),
            style: AppTypography.label(size: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

enum JoinLeaveKind { join, leave }

/// Hilfs-Mapper: aus LiveKit-RemoteParticipant einen WatcherEntry bauen.
/// Identity wird typischerweise `${userId}` sein — wir lesen Name aus
/// der Participant-Metadata wenn vorhanden, sonst fallback auf Identity.
WatcherEntry watcherFromParticipant(lk.RemoteParticipant p) {
  final name = p.name;
  final meta = p.metadata;
  return WatcherEntry(
    identity: p.identity,
    name: (name.isNotEmpty)
        ? name
        : ((meta != null && meta.isNotEmpty) ? meta : p.identity),
  );
}
