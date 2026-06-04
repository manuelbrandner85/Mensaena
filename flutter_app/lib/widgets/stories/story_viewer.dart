/// SKILL: mensaena-features (F59 Stories — Fullscreen-Viewer)
/// Tap auf Story-Avatar → Vollbild mit Progress-Bars, 5s pro Story,
/// Swipe für nächsten User. Auto-record-View beim Anzeigen.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/mega_models.dart';
import '../../repositories/mega_repositories.dart';

class StoryViewer extends StatefulWidget {
  const StoryViewer({required this.stories, super.key});

  final List<Story> stories;

  static Future<void> show(BuildContext context,
      {required List<Story> stories}) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => StoryViewer(stories: stories),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressCtrl;
  int _index = 0;

  static const _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: _storyDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _start();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    super.dispose();
  }

  void _start() {
    _progressCtrl
      ..reset()
      ..forward();
    StoriesRepository.recordView(widget.stories[_index].id);
  }

  void _next() {
    if (_index + 1 >= widget.stories.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index++);
    _start();
  }

  void _previous() {
    if (_index == 0) return;
    setState(() => _index--);
    _start();
  }

  void _pause() => _progressCtrl.stop();
  void _resume() => _progressCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapDown: (d) {
            final dx = d.globalPosition.dx;
            final width = MediaQuery.sizeOf(context).width;
            if (dx < width / 3) {
              _previous();
            } else {
              _next();
            }
          },
          onLongPressStart: (_) => _pause(),
          onLongPressEnd: (_) => _resume(),
          child: Stack(
            children: [
              // Story-Image
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: story.mediaUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                        color: AppColors.bronze),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: const Icon(LucideIcons.imageOff,
                        size: 32, color: AppColors.mute),
                  ),
                ),
              ),

              // Text-Overlay
              if (story.textOverlay != null &&
                  story.textOverlay!.isNotEmpty)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 120,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      story.textOverlay!,
                      style: AppTypography.body(
                          size: 16,
                          color: Colors.white,
                          weight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // Progress-Bars
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    for (int i = 0; i < widget.stories.length; i++) ...[
                      Expanded(
                        child: _ProgressBar(
                          progress: i < _index
                              ? 1.0
                              : (i == _index
                                  ? null
                                  : 0.0),
                          ctrl: i == _index ? _progressCtrl : null,
                        ),
                      ),
                      if (i < widget.stories.length - 1)
                        const SizedBox(width: 3),
                    ],
                  ],
                ),
              ),

              // Header — Author + Close
              Positioned(
                top: 20,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.elevated,
                      backgroundImage: story.authorAvatar != null
                          ? CachedNetworkImageProvider(story.authorAvatar!)
                          : null,
                      child: story.authorAvatar == null
                          ? Text(
                              (story.authorName ?? '?')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: AppTypography.body(
                                  size: 12, color: AppColors.bronze))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        story.authorName ?? '?',
                        style: AppTypography.body(
                            size: 13,
                            color: Colors.white,
                            weight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'common.close'.tr(),
                      icon: const Icon(LucideIcons.x,
                          color: Colors.white),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.ctrl});
  final double? progress;
  final AnimationController? ctrl;

  @override
  Widget build(BuildContext context) {
    if (ctrl != null) {
      return AnimatedBuilder(
        animation: ctrl!,
        builder: (_, __) => _bar(ctrl!.value),
      );
    }
    return _bar(progress ?? 0);
  }

  Widget _bar(double v) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
