/// SKILL: mensaena-features + mensaena-design
/// Mini-Player für einen laufenden Livestream (Telegram-Modell). Erscheint
/// global im DashboardScaffold sobald activeStreamProvider gesetzt ist und
/// der User NICHT im Stream-Screen ist. Tap = zurück in den Stream. Audio
/// läuft durchgehend (Room im StreamRoomHolder).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/active_stream_provider.dart';
import '../../services/stream_room_holder.dart';
import '../effects/bloom.dart';

class ActiveStreamMiniPlayer extends ConsumerStatefulWidget {
  const ActiveStreamMiniPlayer({required this.info, super.key});
  final ActiveStreamInfo info;

  @override
  ConsumerState<ActiveStreamMiniPlayer> createState() =>
      _ActiveStreamMiniPlayerState();
}

class _ActiveStreamMiniPlayerState
    extends ConsumerState<ActiveStreamMiniPlayer>
    with SingleTickerProviderStateMixin {
  Offset _offset = const Offset(16, 150);
  // PERF-FIX: AnimationController statt Timer.periodic (vsync-gekoppelt,
  // pausiert mit TickerMode/Hintergrund).
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _open(BuildContext context) {
    final info = widget.info;
    final title = Uri.encodeComponent(info.channelTitle);
    final r = Uri.encodeComponent(info.roomName);
    context.push(
        '/dashboard/live/$r?title=$title&host=${info.isHost ? '1' : '0'}');
  }

  Future<void> _leave() async {
    await StreamRoomHolder.clear();
    ref.read(activeStreamProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      right: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            final nx = (_offset.dx - d.delta.dx).clamp(8.0, size.width - 188);
            final ny =
                (_offset.dy + d.delta.dy).clamp(40.0, size.height - 220);
            _offset = Offset(nx, ny);
          });
        },
        onTap: () => _open(context),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 184,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF0141C28), Color(0xF6080C14)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x47ECE5D6)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 18,
                    offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PulseBloom(
                      color: AppColors.herzrot,
                      radius: 6,
                      minIntensity: 0.4,
                      maxIntensity: 0.9,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.herzrot,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('chat.liveLabel'.tr(),
                        style: AppTypography.label(
                            size: 8, color: AppColors.herzrotWarm)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _leave,
                      child: const Icon(LucideIcons.x,
                          size: 14, color: AppColors.mute),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  info.channelTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Nur dieser Text rebuildet 1×/s; der teure Container
                    // außenrum bleibt stabil.
                    AnimatedBuilder(
                      animation: _ticker,
                      builder: (_, __) => Text(
                        _fmt(DateTime.now().difference(info.startedAt)),
                        style: AppTypography.mono(
                            size: 11, color: AppColors.bronze),
                      ),
                    ),
                    const Spacer(),
                    const Icon(LucideIcons.expand,
                        size: 12, color: AppColors.mute),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
