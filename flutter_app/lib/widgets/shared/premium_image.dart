/// SKILL: mensaena-design
/// PremiumImage — der app-weite Wrapper für Content-Bilder (Post-Cover,
/// Event-Cover, Marketplace-Listings, Group-Banner, Knowledge-Hero …).
///
/// Garantiert app-weit konsistent:
///   - 12dp Border-Radius (überschreibbar)
///   - Optionaler weicher Dunkel-Verlauf am unteren Rand → Texte/Badges
///     lesen sich darüber sofort, ohne dass man bei jedem Bild manuell
///     einen Container drumherum bauen muss.
///   - Dezenter 1px Innen-Highlight → Bild wirkt "präsent" auf dunkler
///     Cinema-Oberfläche.
///   - Lite-Mode-bewusst: kleinere memCacheWidth/Height auf ARM32-Geräten
///     → kein OOM auf alten Telefonen.
///   - Skeleton-Loading + ImageOff-Fallback statt nacktem grauem Rechteck.
library;

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../repositories/extra_repositories.dart';
import '../../services/device_tier_service.dart';
import '../effects/shimmer_skeleton.dart';

// Diagnose: jede fehlgeschlagene Bild-URL EINMAL pro Session nach error_logs
// melden (mit URL + Fehler). So lässt sich „Bilder werden nicht angezeigt"
// gezielt eingrenzen (403/404/Timeout/Decode) statt im Dunkeln zu raten.
final Set<String> _loggedImageFailures = <String>{};
void _logImageFailure(String url, Object error) {
  if (!_loggedImageFailures.add(url)) return;
  unawaited(ErrorLogsRepository.log(
    errorType: 'image_load_failed',
    message: '$url :: $error',
  ));
}

class PremiumImage extends ConsumerWidget {
  const PremiumImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.bottomGradient = false,
    this.innerHighlight = true,
    this.heroTag,
    super.key,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// `true` → weicher Dunkel-Verlauf vom Bild-Boden nach oben. Pflicht
  /// wenn Texte/Buttons über dem Bild sitzen (Hero-Card, Featured-Tile).
  final bool bottomGradient;

  /// 1px subtiler Innen-Highlight am oberen Rand → "präsentes" Foto-Feel.
  /// Im Lite-Mode aus.
  final bool innerHighlight;

  /// Hero-Tag für die Card→Detail-Transition (#A8). Nur Premium-Mode
  /// nutzt sie wirklich — Lite-Mode rendert das Bild ohne Hero-Wrapper.
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLite = ref.watch(liteModeActiveProvider);
    final radius = borderRadius ?? BorderRadius.circular(12);
    // Lite-Mode: deutlich kleinere Decode-Größe. Spart RAM auf ARM32.
    final decodeW =
        isLite ? (width != null ? width!.toInt() * 2 : 480) : null;
    final decodeH =
        isLite ? (height != null ? height!.toInt() * 2 : null) : null;

    Widget image;
    if (url == null || url!.isEmpty) {
      image = _buildPlaceholder(width, height, radius);
    } else {
      image = CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: decodeW,
        memCacheHeight: decodeH,
        fadeInDuration: isLite
            ? Duration.zero
            : const Duration(milliseconds: 200),
        placeholder: (_, __) => isLite
            ? Container(
                width: width,
                height: height,
                color: AppColors.elevated,
              )
            : ShimmerBox(
                width: width ?? double.infinity,
                height: height ?? 180,
                borderRadius: radius.topLeft.x,
              ),
        errorWidget: (_, failedUrl, error) {
          _logImageFailure(failedUrl, error);
          return _buildPlaceholder(width, height, radius);
        },
      );
    }

    // Bottom-Gradient + Innen-Highlight als Stack-Overlay. Stack nur
    // bauen wenn nötig — saubere Trees auch ohne Effekte.
    final wantsGradient = bottomGradient;
    final wantsHighlight = innerHighlight && !isLite;
    if (wantsGradient || wantsHighlight) {
      image = Stack(
        fit: StackFit.passthrough,
        children: [
          image,
          if (wantsGradient)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.voidColor.withValues(alpha: 0.78),
                        AppColors.voidColor.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.6],
                    ),
                  ),
                ),
              ),
            ),
          if (wantsHighlight)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    Widget clipped = ClipRRect(borderRadius: radius, child: image);
    if (heroTag != null && !isLite) {
      clipped = Hero(tag: heroTag!, child: clipped);
    }
    return clipped;
  }

  Widget _buildPlaceholder(double? w, double? h, BorderRadius radius) {
    return Container(
      width: w,
      height: h ?? 140,
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: const Icon(LucideIcons.imageOff,
          size: 24, color: AppColors.mute),
    );
  }
}
