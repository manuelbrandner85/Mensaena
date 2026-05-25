/// SKILL: mensaena-features
/// VideoPreviewModal — Selbst-Vorschau (Front-Kamera) vor einem Videoanruf.
///
/// Pendant zu Web `VideoPreviewModal.tsx`. Zeigt das eigene Kamerabild
/// (gespiegelt) plus 2 Buttons: Abbrechen / Starten.
///
/// LiveKit-Track wird in initState erzeugt und in dispose sauber gestoppt
/// — auch wenn der User das Sheet wegswiped, lebt kein dangling Track.
library;

import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class VideoPreviewModal extends StatefulWidget {
  const VideoPreviewModal({
    required this.peerName,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final String peerName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<VideoPreviewModal> createState() => _VideoPreviewModalState();

  /// Convenience-Wrapper: zeigt das Modal als BottomSheet und ruft
  /// [onConfirm] auf wenn der User "Starten" tippt.
  static Future<bool> show(
    BuildContext context, {
    required String peerName,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.voidColor,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => VideoPreviewModal(
        peerName: peerName,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }
}

class _VideoPreviewModalState extends State<VideoPreviewModal> {
  lk.LocalVideoTrack? _track;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startPreview();
  }

  Future<void> _startPreview() async {
    final cam = await Permission.camera.request();
    if (cam.isDenied || cam.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'videoPreview.cameraDenied'.tr();
      });
      return;
    }
    try {
      final track = await lk.LocalVideoTrack.createCameraTrack(
        const lk.CameraCaptureOptions(
          cameraPosition: lk.CameraPosition.front,
          params: lk.VideoParametersPresets.h540_169,
        ),
      );
      if (!mounted) {
        await track.stop();
        await track.dispose();
        return;
      }
      setState(() {
        _track = track;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _stopTrack() async {
    final t = _track;
    _track = null;
    if (t == null) return;
    try {
      await t.stop();
    } catch (_) {}
    try {
      await t.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    // Fire-and-forget: dispose ist sync, aber Track-Stop ist async.
    _stopTrack();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.7;
    return SafeArea(
      child: SizedBox(
        height: h,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mute.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'videoPreview.title'.tr(namedArgs: {'name': widget.peerName}),
                style: AppTypography.display(size: 18, color: AppColors.ink),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'videoPreview.subtitle'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: AppColors.elevated,
                    alignment: Alignment.center,
                    child: _buildPreview(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CircleBtn(
                  icon: LucideIcons.x,
                  color: AppColors.mute,
                  label: 'common.cancel'.tr(),
                  onTap: () async {
                    await _stopTrack();
                    widget.onCancel();
                  },
                ),
                _CircleBtn(
                  icon: LucideIcons.video,
                  color: AppColors.leben,
                  label: 'videoPreview.start'.tr(),
                  onTap: () async {
                    await _stopTrack();
                    widget.onConfirm();
                  },
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_loading) {
      return const CircularProgressIndicator(color: AppColors.leben);
    }
    final err = _error;
    if (err != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          err,
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 13, color: AppColors.herzrotWarm),
        ),
      );
    }
    final t = _track;
    if (t == null) {
      return Icon(LucideIcons.videoOff,
          size: 48, color: AppColors.mute.withValues(alpha: 0.6));
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(math.pi),
      child: lk.VideoTrackRenderer(
        t,
        fit: rtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.label(size: 11, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}
