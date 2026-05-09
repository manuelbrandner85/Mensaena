import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'update_models.dart';

/// Nicht-blockierendes Bottom-Sheet das nach einem Update (APK ODER
/// Shorebird-Patch) angezeigt wird, sobald die App das nächste Mal
/// startet. Zeigt user-freundliche Changelog-Einträge.
class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({
    super.key,
    required this.releases,
    this.scroll,
  });

  /// Releases die der User seit dem letzten Launch verpasst hat,
  /// neuestes zuerst.
  final List<AppRelease> releases;
  final ScrollController? scroll;

  static Future<void> show(
    BuildContext context, {
    required List<AppRelease> releases,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scroll) =>
            WhatsNewSheet(releases: releases, scroll: scroll),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = releases.expand((r) => r.entries).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.stone300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.celebration_outlined,
                  color: AppColors.primary500,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Was ist neu in Mensaena',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                color: AppColors.ink400,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Wir haben Mensaena im Hintergrund verbessert.',
                style: TextStyle(color: AppColors.ink400),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _Tile(entry: entries[i]),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Verstanden',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entry});
  final ChangelogEntry entry;

  Color get _accent {
    switch (entry.type) {
      case ChangelogType.feature:
        return AppColors.primary500;
      case ChangelogType.improvement:
        return const Color(0xFF3B82F6);
      case ChangelogType.fix:
        return const Color(0xFFD97706);
      case ChangelogType.notice:
        return const Color(0xFF8B5CF6);
      case ChangelogType.unknown:
        return AppColors.ink400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stone200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(entry.type.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.type.label,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink800,
                  ),
                ),
                if ((entry.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink700,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
