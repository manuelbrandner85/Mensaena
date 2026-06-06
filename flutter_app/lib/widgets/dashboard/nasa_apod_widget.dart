/// SKILL: mensaena-features + mensaena-design
/// NASA Astronomy Picture of the Day — taegliches Bild + Beschreibung.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/nasa_apod_service.dart';
import '../effects/glass_card.dart';
import '../../utils/safe_launch.dart';

final _apodProvider = FutureProvider<NasaApod?>((ref) async {
  return NasaApodService.today();
});

class NasaApodWidget extends ConsumerWidget {
  const NasaApodWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_apodProvider);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.image,
                  size: 16, color: AppColors.tealSoft),
              const SizedBox(width: 8),
              Text('nasaApod.title'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
              const Spacer(),
              Text('NASA APOD', style: AppTypography.caption()),
            ],
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const SizedBox(
              height: 180,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.tealSoft),
              ),
            ),
            error: (_, __) => Text('nasaApod.error'.tr(),
                style: AppTypography.caption()),
            data: (apod) {
              if (apod == null) {
                return Text('nasaApod.empty'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.mute));
              }
              return _ApodContent(apod: apod);
            },
          ),
        ],
      ),
    );
  }
}

class _ApodContent extends StatefulWidget {
  const _ApodContent({required this.apod});
  final NasaApod apod;

  @override
  State<_ApodContent> createState() => _ApodContentState();
}

class _ApodContentState extends State<_ApodContent> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final apod = widget.apod;
    final isImage = apod.mediaType == 'image';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () async {
                final url = apod.hdUrl ?? apod.url;
                if (url.isNotEmpty) {
                  await safeLaunch(url,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: CachedNetworkImage(
                imageUrl: apod.url,
                fit: BoxFit.cover,
                width: double.infinity,
                // MEMORY-FIX: NASA-APOD-Bilder sind oft mehrere MB groß.
                // Auf 1000px Breite decken → reicht für die Card-Vorschau.
                memCacheWidth: 1000,
                placeholder: (_, __) => Container(
                  height: 200,
                  color: AppColors.elevated,
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.elevated,
                  alignment: Alignment.center,
                  child: const Icon(LucideIcons.imageOff,
                      color: AppColors.mute, size: 28),
                ),
              ),
            ),
          )
        else
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.video,
                size: 28, color: AppColors.mute),
          ),
        const SizedBox(height: 8),
        Text(
          apod.title,
          style: AppTypography.body(
              size: 13,
              color: AppColors.ink,
              weight: FontWeight.w700),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            apod.explanation,
            maxLines: _expanded ? 12 : 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
                size: 12, color: AppColors.inkSoft, height: 1.4),
          ),
        ),
        if (apod.copyright != null && apod.copyright!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('© ${apod.copyright!.trim()}',
              style: AppTypography.caption()),
        ],
      ],
    );
  }
}
