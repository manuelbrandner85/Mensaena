/// SKILL: mensaena-features (P3) — Voicemail-Liste.
/// Zeigt alle eigenen Voicemails (callee_id = me).
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/calls_repository.dart';
import '../../../widgets/effects/glass_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

final voicemailsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return CallsRepository.voicemailsForMe();
});

class VoicemailScreen extends ConsumerStatefulWidget {
  const VoicemailScreen({super.key});
  @override
  ConsumerState<VoicemailScreen> createState() => _VoicemailScreenState();
}

class _VoicemailScreenState extends ConsumerState<VoicemailScreen> {
  final _player = AudioPlayer();
  String? _playingId;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(Map<String, dynamic> v) async {
    final id = v['id'] as String;
    final url = v['audio_url'] as String;
    if (_playingId == id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = id);
    try {
      await _player.play(UrlSource(url));
      if (!(v['is_listened'] as bool? ?? false)) {
        await CallsRepository.voicemailMarkListened(id);
        ref.invalidate(voicemailsProvider);
      }
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(voicemailsProvider);
    final df = DateFormat('dd.MM. HH:mm');
    return DashboardScaffold(
      title: 'voicemail.title'.tr(),
      currentRoute: '/dashboard/voicemail',
      onRefresh: () async {
        ref.invalidate(voicemailsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.voicemail,
                      size: 32, color: AppColors.mute),
                  const SizedBox(height: 8),
                  Text('voicemail.empty'.tr(),
                      style: AppTypography.caption()),
                ]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final v = rows[i];
              final caller = v['caller'] as Map<String, dynamic>?;
              final name =
                  (caller?['display_name'] as String?) ?? 'mensaena';
              final avatar = caller?['avatar_url'] as String?;
              final ts = DateTime.tryParse(v['created_at'] as String? ?? '')?.toUtc() ??
                  DateTime.now();
              final dur = (v['duration_seconds'] as num?)?.toInt() ?? 0;
              final isListened = v['is_listened'] as bool? ?? false;
              final playing = _playingId == v['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    ClipOval(
                      child: avatar != null
                          ? CachedNetworkImage(
                              imageUrl: avatar,
                              width: 40,
                              height: 40,
                              memCacheWidth: 80,
                              memCacheHeight: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              color: AppColors.elevated,
                              alignment: Alignment.center,
                              child: Text(name[0].toUpperCase(),
                                  style: AppTypography.body(
                                      size: 14,
                                      color: AppColors.ink,
                                      weight: FontWeight.w700)),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.ink,
                                  weight: isListened
                                      ? FontWeight.w500
                                      : FontWeight.w800)),
                          Text(
                              '${df.format(ts)} · ${dur}s',
                              style: AppTypography.caption()),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'common.pause'.tr(),
                      onPressed: () => _play(v),
                      icon: Icon(
                        playing ? LucideIcons.pause : LucideIcons.play,
                        size: 22,
                        color: AppColors.bronze,
                      ),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
