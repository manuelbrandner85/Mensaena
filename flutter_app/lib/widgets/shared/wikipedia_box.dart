/// SKILL: mensaena-features + mensaena-design
/// Wikipedia-Box — "Lerne mehr"-Card mit Snippet + Link zur Wiki-Seite.
/// Lädt automatisch beim ersten Build, cached pro Term im StatefulWidget.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/wikipedia_service.dart';

class WikipediaBox extends StatefulWidget {
  const WikipediaBox({
    required this.term,
    this.lang = 'de',
    this.maxLines = 5,
    super.key,
  });

  final String term;
  final String lang;
  final int maxLines;

  @override
  State<WikipediaBox> createState() => _WikipediaBoxState();
}

class _WikipediaBoxState extends State<WikipediaBox> {
  WikiSummary? _data;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await WikipediaService.summary(widget.term, lang: widget.lang);
    if (mounted) {
      setState(() {
        _data = s;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Container(
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        child: Text('wiki.loading'.tr(),
            style: AppTypography.body(size: 12, color: AppColors.mute)),
      );
    }
    final d = _data;
    if (d == null) return const SizedBox.shrink();
    return InkWell(
      onTap: () => launchUrl(Uri.parse(d.url),
          mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.tealSoft.withValues(alpha: 0.15),
              AppColors.tealSoft.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: AppColors.tealSoft.withValues(alpha: 0.35), width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('W',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.tealSoft)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                              size: 14,
                              color: AppColors.ink,
                              weight: FontWeight.w700)),
                      if (d.description != null && d.description!.isNotEmpty)
                        Text(d.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label(
                                size: 9, color: AppColors.mute)),
                    ],
                  ),
                ),
                if (d.thumbnailUrl != null) ...[
                  const SizedBox(width: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: d.thumbnailUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(d.extract,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                    size: 12, color: AppColors.inkSoft, height: 1.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('wiki.source'.tr(),
                    style: AppTypography.label(
                        size: 9, color: AppColors.mute)),
                const Spacer(),
                Icon(LucideIcons.externalLink,
                    size: 11,
                    color: AppColors.tealSoft.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text('common.read'.tr(),
                    style: AppTypography.label(
                        size: 10, color: AppColors.tealSoft)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
