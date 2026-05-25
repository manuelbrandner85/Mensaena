/// SKILL: mensaena-design
/// Wrapper um CachedNetworkImage mit garantierten Dimensions.
///
/// Vorher: viele Screens nutzten CachedNetworkImage(url) ohne width/height.
/// Flutter muss zweimal layouten (placeholder mit 0x0 → image-loaded mit
/// echten Pixeln → resize) = Layout-Thrash + Scroll-Jank.
///
/// Jetzt: feste size oder width/height von aussen. Placeholder + Image
/// haben dieselben Dimensions, kein Re-Layout.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class SizedAvatarImage extends StatelessWidget {
  /// Quadratischer Avatar — `size` setzt Width + Height.
  const SizedAvatarImage({
    required this.url,
    required this.size,
    this.fallbackInitial,
    this.borderRadius,
    super.key,
  })  : width = size,
        height = size;

  /// Beliebige Dimensions (z.B. Cover-Bild im Profile-Header).
  const SizedAvatarImage.sized({
    required this.url,
    required this.width,
    required this.height,
    this.fallbackInitial,
    this.borderRadius,
    super.key,
  }) : size = 0;

  final String? url;
  final double size;
  final double width;
  final double height;
  final String? fallbackInitial;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(width / 2);
    final placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: AppColors.bronze.withValues(alpha: 0.18),
      ),
      alignment: Alignment.center,
      child: fallbackInitial != null && fallbackInitial!.isNotEmpty
          ? Text(
              fallbackInitial!.toUpperCase(),
              style: AppTypography.display(
                size: width * 0.4,
                color: AppColors.bronze,
              ),
            )
          : null,
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: (width * 2).toInt(),
        memCacheHeight: (height * 2).toInt(),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}
