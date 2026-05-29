/// SKILL: mensaena-features (P9) — Foto-Galerie für Events.
/// Liste mit Thumbnails + Upload-Button für Teilnehmer.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import '../shared/image_lightbox.dart';

final eventPhotosProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, eventId) async {
  try {
    final rows = await sb
        .from('event_photos')
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List).whereType<Map<String, dynamic>>().toList();
  } catch (_) {
    return const [];
  }
});

class EventPhotosGallery extends ConsumerStatefulWidget {
  const EventPhotosGallery({required this.eventId, super.key});
  final String eventId;
  @override
  ConsumerState<EventPhotosGallery> createState() =>
      _EventPhotosGalleryState();
}

class _EventPhotosGalleryState extends ConsumerState<EventPhotosGallery> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 80, maxWidth: 1600);
      if (x == null || !mounted) return;
      setState(() => _uploading = true);
      final bytes = await x.readAsBytes();
      final ext = x.path.split('.').last.toLowerCase();
      // contentType setzen, sonst speichert Supabase als octet-stream und
      // das Bild wird nicht als Bild ausgeliefert (Punkt 8). uid-Prefix für
      // die "own delete"-Policy.
      final mime = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
      final path =
          '$uid/${widget.eventId}-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await sb.storage.from('event-photos').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      final url = sb.storage.from('event-photos').getPublicUrl(path);
      await sb.from('event_photos').insert({
        'event_id': widget.eventId,
        'user_id': uid,
        'image_url': url,
      });
      ref.invalidate(eventPhotosProvider(widget.eventId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('events.photo_upload_failed'.tr())));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(eventPhotosProvider(widget.eventId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(LucideIcons.camera,
              size: 16, color: AppColors.bronze),
          const SizedBox(width: 8),
          Text('events.photos'.tr(),
              style: AppTypography.label(size: 11)),
          const Spacer(),
          TextButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(LucideIcons.upload, size: 14),
            label: Text('events.add_photo'.tr()),
          ),
        ]),
        const SizedBox(height: 8),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.bronze)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (photos) {
            if (photos.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('events.no_photos'.tr(),
                    style: AppTypography.caption()),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: photos.length,
              itemBuilder: (_, i) {
                final url = photos[i]['image_url'] as String;
                return GestureDetector(
                  onTap: () => ImageLightbox.open(
                    context,
                    urls: photos
                        .map((p) => p['image_url'] as String)
                        .toList(),
                    initialIndex: i,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      memCacheWidth: 300,
                      memCacheHeight: 300,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.elevated,
                        alignment: Alignment.center,
                        child: const Icon(LucideIcons.imageOff,
                            color: AppColors.mute, size: 18),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
