import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import 'image_lightbox.dart';

/// SKILL: mensaena-design + mensaena-features
/// Image-Carousel — PageView mit Indicator-Dots + Tap-zur-Lightbox.
/// 1:1 zu Web PostCard.tsx + Marketplace-Detail.
class ImageCarousel extends StatefulWidget {
  const ImageCarousel({
    required this.urls,
    this.height = 200,
    this.borderRadius = 12,
    super.key,
  });

  final List<String> urls;
  final double height;
  final double borderRadius;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late final PageController _ctrl;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) return const SizedBox.shrink();
    if (widget.urls.length == 1) {
      // Single image — no carousel needed
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: GestureDetector(
          onTap: () => ImageLightbox.open(context, urls: widget.urls),
          child: CachedNetworkImage(
            imageUrl: widget.urls.first,
            height: widget.height,
            width: double.infinity,
            fit: BoxFit.cover,
            // RAM-Limit: decoded auf max 2x logical pixels.
            memCacheHeight: (widget.height * 2).toInt(),
            placeholder: (_, __) => _placeholder(),
            errorWidget: (_, __, ___) => _errorBox(),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _ctrl,
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => ImageLightbox.open(
                  context,
                  urls: widget.urls,
                  initialIndex: i,
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  memCacheHeight: (widget.height * 2).toInt(),
                  placeholder: (_, __) => _placeholder(),
                  errorWidget: (_, __, ___) => _errorBox(),
                ),
              ),
            ),
            // Index-Counter top-right
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_index + 1} / ${widget.urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            // Indicator-Dots bottom-center
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.urls.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.amber
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.elevated,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.amber),
        ),
      );

  Widget _errorBox() => Container(
        color: AppColors.elevated,
        alignment: Alignment.center,
        child: const Icon(LucideIcons.imageOff, color: AppColors.mute),
      );
}
