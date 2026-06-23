/// SKILL: mensaena-design (Cinema-Hyperreal / Higgsfield-Assets)
/// CinematicVideoBackdrop — loopendes Stimmungs-Video mit hartem
/// Standbild-Fallback.
///
/// Spielt das gebündelte, stumme Loop-Video NUR auf EffectsProfile.full.
/// In ALLEN anderen Fällen (reduced/none, Init noch nicht fertig,
/// Init-Fehler) rendert es das frame-identische Standbild über
/// [CinematicBackdrop] — nie ein leerer Screen, nie ein Ruckler beim
/// Umschalten, weil Video-Frame 1 == Standbild (Higgsfield image-to-video
/// mit Start=End-Frame).
///
/// Akku-Disziplin: Controller wird bei Profil-Downgrade pausiert und beim
/// Verlassen disposed; Video ist tonlos (keine Audio-Session).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../providers/effects_gate_provider.dart';
import 'cinematic_backdrop.dart';

class CinematicVideoBackdrop extends ConsumerStatefulWidget {
  const CinematicVideoBackdrop({
    required this.videoAsset,
    required this.stillAsset,
    this.topScrim = 0.35,
    this.bottomScrim = 0.85,
    this.alwaysPlay = false,
    super.key,
  });

  final String videoAsset;
  final String stillAsset;
  final double topScrim;
  final double bottomScrim;

  /// Wenn true, spielt das Video unabhängig vom EffectsProfile (z. B. wenn der
  /// User den Video-Hintergrund explizit aktiviert hat) — läuft GPU-dekodiert
  /// auch auf schwächeren Geräten flüssig. Nur Decoder-/Asset-Fehler oder
  /// reduceMotion fallen dann noch aufs Standbild zurück.
  final bool alwaysPlay;

  @override
  ConsumerState<CinematicVideoBackdrop> createState() =>
      _CinematicVideoBackdropState();
}

class _CinematicVideoBackdropState
    extends ConsumerState<CinematicVideoBackdrop> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  bool _failed = false;

  Future<void> _init() async {
    if (_ctrl != null || _failed) return;
    final ctrl = VideoPlayerController.asset(widget.videoAsset);
    _ctrl = ctrl;
    try {
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      await ctrl.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // Decoder/Asset-Fehler → dauerhaft aufs Standbild.
      if (mounted) setState(() => _failed = true);
      _ctrl = null;
      try {
        await ctrl.dispose();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = CinematicBackdrop(
      asset: widget.stillAsset,
      topScrim: widget.topScrim,
      bottomScrim: widget.bottomScrim,
    );

    final profile = ref.watch(effectsProfileProvider);
    // alwaysPlay (User hat Video-Hintergrund aktiv): unabhängig vom Profil
    // abspielen, nur reduceMotion (profile.isOff) bleibt beim Standbild.
    // Sonst (Landing): wie gehabt nur bei full.
    final allowVideo = widget.alwaysPlay ? !profile.isOff : profile.isFull;
    if (!allowVideo || _failed) {
      // Downgrade / aus → Video pausieren, Bild zeigen.
      _ctrl?.pause();
      return still;
    }

    if (!_ready) {
      _init();
      return still;
    }

    final ctrl = _ctrl!;
    if (!ctrl.value.isPlaying) ctrl.play();
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: ctrl.value.size.width,
              height: ctrl.value.size.height,
              child: VideoPlayer(ctrl),
            ),
          ),
          // Identischer Scrim wie das Standbild → nahtloser Wechsel.
          IgnorePointer(
            child: CinematicBackdropScrim(
              topScrim: widget.topScrim,
              bottomScrim: widget.bottomScrim,
            ),
          ),
        ],
      ),
    );
  }
}
