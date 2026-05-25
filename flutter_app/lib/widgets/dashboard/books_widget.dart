/// SKILL: mensaena-features + mensaena-design
/// BooksWidget — horizontale Karten mit Open-Library-Empfehlungen.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/books_service.dart';
import '../effects/glass_card.dart';

final _booksProvider = FutureProvider<List<BookRec>>((ref) async {
  return BooksService.recommendations();
});

class BooksWidget extends ConsumerWidget {
  const BooksWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_booksProvider);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                const Icon(LucideIcons.bookOpen,
                    size: 16, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text(
                  'books.title'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700),
                ),
                const Spacer(),
                Text('books.source'.tr(),
                    style: AppTypography.caption()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.bronze),
              ),
              error: (_, __) => Center(
                child: Text('books.error'.tr(),
                    style: AppTypography.caption()),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text('books.empty'.tr(),
                        style: AppTypography.body(
                            size: 12, color: AppColors.mute)),
                  );
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  padding: const EdgeInsets.only(right: 14),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _BookCard(book: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});
  final BookRec book;

  Future<void> _open() async {
    final url = 'https://openlibrary.org${book.key}';
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (_) {/* no browser */}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 120,
                height: 160,
                child: book.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: book.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.elevated,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.elevated,
                          alignment: Alignment.center,
                          child: const Icon(LucideIcons.bookOpen,
                              color: AppColors.mute),
                        ),
                      )
                    : Container(
                        color: AppColors.elevated,
                        alignment: Alignment.center,
                        child: const Icon(LucideIcons.bookOpen,
                            color: AppColors.mute, size: 28),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                  size: 11, color: AppColors.ink, weight: FontWeight.w600),
            ),
            if (book.authorName.isNotEmpty)
              Text(
                book.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(),
              ),
          ],
        ),
      ),
    );
  }
}
