import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-features + mensaena-design
/// Voice-Message-Bubble — Play/Pause + Progress-Bar.
/// 1:1 zu Web VoiceMessage-Component.
class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    required this.url,
    required this.durationSeconds,
    this.mine = false,
    super.key,
  });

  final String url;
  final int durationSeconds;
  final bool mine;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late final AudioPlayer _player;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration? _total;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
      if (s == PlayerState.completed) {
        setState(() => _position = Duration.zero);
      }
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _total ?? Duration(seconds: widget.durationSeconds);
    final progress = total.inMilliseconds > 0
        ? (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final accent = widget.mine ? AppColors.amber : AppColors.bronze;
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.22),
                shape: BoxShape.circle,
                border: Border.all(
                    color: accent.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Icon(
                _playing ? LucideIcons.pause : LucideIcons.play,
                size: 16,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Progress + timer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pseudo-Waveform (8 vertical bars, animated by progress)
                SizedBox(
                  height: 18,
                  child: Row(
                    children: List.generate(16, (i) {
                      final filled = (i / 16) < progress;
                      // Pseudo-random height pattern (deterministic by index)
                      final h = 4.0 + ((i * 7) % 12);
                      return Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            height: h,
                            decoration: BoxDecoration(
                              color: filled
                                  ? accent
                                  : accent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _playing || _position.inSeconds > 0
                      ? _fmt(_position)
                      : _fmt(total),
                  style: AppTypography.mono(
                      size: 10, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
