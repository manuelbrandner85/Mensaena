import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design
/// Image-Lightbox — Vollbild-Viewer mit Pinch-Zoom + Swipe-Down zum Schliessen.
/// 1:1 zu Web MobileImageViewer.tsx — Tap auf jedes Bild oeffnet diese View.
///
/// Usage:
///   ImageLightbox.open(context, urls: ['https://…'], initialIndex: 0);
class ImageLightbox extends StatefulWidget {
  const ImageLightbox({
    required this.urls,
    this.initialIndex = 0,
    super.key,
  });

  final List<String> urls;
  final int initialIndex;

  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
  }) {
    if (urls.isEmpty) return Future.value();
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.92),
        pageBuilder: (_, __, ___) => ImageLightbox(
          urls: urls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }

  @override
  State<ImageLightbox> createState() => _ImageLightboxState();
}

class _ImageLightboxState extends State<ImageLightbox> {
  late int _index;
  late final PageController _ctrl;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dragOpacity =
        (1 - (_dragOffset.abs() / 400).clamp(0, 1)).toDouble();
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: dragOpacity),
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragUpdate: (d) =>
              setState(() => _dragOffset += d.delta.dy),
          onVerticalDragEnd: (d) {
            if (_dragOffset.abs() > 120) {
              Navigator.of(context).pop();
            } else {
              setState(() => _dragOffset = 0);
            }
          },
          child: Stack(
            children: [
              Transform.translate(
                offset: Offset(0, _dragOffset),
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: widget.urls.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => Center(
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.5,
                      child: CachedNetworkImage(
                        imageUrl: widget.urls[i],
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const CircularProgressIndicator(
                            color: AppColors.bronze),
                        errorWidget: (_, __, ___) => const Icon(
                          LucideIcons.imageOff,
                          color: AppColors.mute,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Close-Button
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x,
                      color: Colors.white, size: 24),
                ),
              ),
              // Index-Indicator falls Multi-Image
              if (widget.urls.length > 1)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.urls.length}',
                        style: AppTypography.mono(
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
