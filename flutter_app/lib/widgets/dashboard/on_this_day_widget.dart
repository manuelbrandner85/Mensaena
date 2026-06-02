/// SKILL: mensaena-features + mensaena-design
/// Wikipedia "On This Day" — heute vor X Jahren.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/on_this_day_service.dart';
import '../effects/glass_card.dart';
import '../../utils/safe_launch.dart';

final _onThisDayProvider =
    FutureProvider<List<OnThisDayEvent>>((ref) async {
  return OnThisDayService.today(lang: 'de');
});

class OnThisDayWidget extends ConsumerWidget {
  const OnThisDayWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_onThisDayProvider);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                const Icon(LucideIcons.scroll,
                    size: 16, color: AppColors.amber),
                const SizedBox(width: 8),
                Text('onThisDay.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
                const Spacer(),
                Text('Wikipedia', style: AppTypography.caption()),
              ],
            ),
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const SizedBox(
              height: 140,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.amber),
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text('onThisDay.error'.tr(),
                  style: AppTypography.caption()),
            ),
            data: (events) {
              if (events.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text('onThisDay.empty'.tr(),
                      style: AppTypography.body(
                          size: 12, color: AppColors.mute)),
                );
              }
              return SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: events.length,
                  padding: const EdgeInsets.only(right: 14),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _EventCard(event: events[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final OnThisDayEvent event;

  Future<void> _open() async {
    final url = event.articleUrl;
    if (url == null || url.isEmpty) return;
    try {
      await safeLaunch(url,
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final yearsAgo = DateTime.now().year - event.year;
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.thumbnail != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: event.thumbnail!,
                  height: 90,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 90,
                    color: AppColors.elevated,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 90,
                    color: AppColors.elevated,
                  ),
                ),
              )
            else
              Container(
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(LucideIcons.bookOpen,
                    color: AppColors.amber.withValues(alpha: 0.4),
                    size: 28),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.15),
                border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                yearsAgo > 0
                    ? 'onThisDay.yearsAgo'
                        .tr(namedArgs: {'n': '$yearsAgo'})
                    : '${event.year}',
                style: AppTypography.mono(
                    size: 10, color: AppColors.amberWarm),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                  size: 11, color: AppColors.ink, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
