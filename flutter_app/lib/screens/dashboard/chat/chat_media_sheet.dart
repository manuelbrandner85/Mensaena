/// SKILL: mensaena-features + mensaena-design (#C6)
/// Geteiltes-Medien-Album einer Konversation. Sammelt alle Bilder aus den
/// Nachrichten (Markdown `![](url)` im content) und zeigt sie als Grid;
/// Tap → Lightbox. Reines Client-Feature über bestehende messages-Daten.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/conversations_repository.dart';
import '../../../widgets/shared/image_lightbox.dart';
import '../../../widgets/shared/premium_image.dart';

class ChatMediaSheet {
  const ChatMediaSheet._();

  static final _imgRegex = RegExp(r'!\[[^\]]*\]\((https?://[^\s\)]+)\)');

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => _MediaGrid(
          conversationId: conversationId,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  /// Lädt die letzten 500 Nachrichten der Konversation und extrahiert alle
  /// Bild-URLs (neueste zuerst). Best-effort, leere Liste bei Fehler.
  static Future<List<String>> loadImages(String conversationId) async {
    final rows =
        await MessagesRepository.recentContents(conversationId);
    final urls = <String>[];
    for (final r in rows) {
      final content = r['content'] as String? ?? '';
      for (final m in _imgRegex.allMatches(content)) {
        final u = m.group(1);
        if (u != null) urls.add(u);
      }
    }
    return urls;
  }
}

class _MediaGrid extends StatefulWidget {
  const _MediaGrid({
    required this.conversationId,
    required this.scrollController,
  });
  final String conversationId;
  final ScrollController scrollController;

  @override
  State<_MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends State<_MediaGrid> {
  late Future<List<String>> _future;

  @override
  void initState() {
    super.initState();
    _future = ChatMediaSheet.loadImages(widget.conversationId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const SizedBox(width: 16),
            const Icon(LucideIcons.image, size: 16, color: AppColors.bronze),
            const SizedBox(width: 8),
            Text('chat.sharedMedia'.tr(),
                style: AppTypography.display(size: 16, color: AppColors.ink)),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: FutureBuilder<List<String>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.bronze),
                  ),
                );
              }
              final urls = snap.data ?? const [];
              if (urls.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.imageOff,
                          size: 30, color: AppColors.mute),
                      const SizedBox(height: 10),
                      Text('chat.noSharedMedia'.tr(),
                          style: AppTypography.caption()),
                    ],
                  ),
                );
              }
              return GridView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: urls.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => ImageLightbox.open(
                    context,
                    urls: urls,
                    initialIndex: i,
                  ),
                  child: PremiumImage(
                    url: urls[i],
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    innerHighlight: false,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
