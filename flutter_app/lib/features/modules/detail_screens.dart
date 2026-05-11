import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/glow_button.dart';
import '../../services/supabase/supabase_service.dart';

/// Generischer Provider fuer Detail-Screens — laedt eine Row anhand der ID.
final _byIdProvider =
    FutureProvider.family<Map<String, dynamic>?, ({String table, String id})>(
        (ref, q) async {
  final res = await supabase.client.from(q.table).select().eq('id', q.id).maybeSingle();
  return res;
});

class WikiArticleScreen extends ConsumerWidget {
  final String articleId;
  const WikiArticleScreen({super.key, required this.articleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final article = ref.watch(_byIdProvider((table: 'knowledge_articles', id: articleId)));
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'WIKI'),
      body: SafeArea(
        child: article.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (a) {
            if (a == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((a['title'] as String?) ?? '', style: MnTypography.display(size: 28)),
                const SizedBox(height: 16),
                MarkdownBody(
                  data: (a['content'] as String?) ?? '',
                  styleSheet: _mdStyle(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  MarkdownStyleSheet _mdStyle(BuildContext ctx) {
    return MarkdownStyleSheet(
      h1: MnTypography.display(size: 24),
      h2: MnTypography.display(size: 20),
      p: MnTypography.body(size: 16, color: MnColors.inkSoft, height: 1.7),
      code: MnTypography.mono(color: MnColors.amber),
      codeblockDecoration: BoxDecoration(
        color: MnColors.surface,
        borderRadius: BorderRadius.circular(MnDimensions.radiusInput),
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: MnColors.amber, width: 3)),
      ),
      a: MnTypography.body(color: MnColors.teal),
    );
  }
}

class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(_byIdProvider((table: 'events', id: eventId)));
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'EVENT'),
      body: SafeArea(
        child: event.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (e) {
            if (e == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((e['title'] as String?) ?? '', style: MnTypography.display(size: 24)),
                const SizedBox(height: 8),
                _row(LucideIcons.calendar, _formatDate(e['starts_at'] as String?)),
                if ((e['location'] as String?)?.isNotEmpty == true)
                  _row(LucideIcons.mapPin, e['location'] as String),
                const SizedBox(height: 16),
                Text(
                  (e['description'] as String?) ?? '',
                  style: MnTypography.body(color: MnColors.inkSoft),
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: 'Teilnehmen',
                  variant: GlowVariant.primary,
                  fullWidth: true,
                  onPressed: () {},
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: MnColors.amber),
            const SizedBox(width: 8),
            Text(text, style: MnTypography.body(color: MnColors.inkSoft)),
          ],
        ),
      );

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}.${d.month}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(_byIdProvider((table: 'groups', id: groupId)));
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'GRUPPE'),
      body: SafeArea(
        child: group.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (g) {
            if (g == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((g['name'] as String?) ?? '', style: MnTypography.display(size: 24)),
                const SizedBox(height: 8),
                Text(
                  (g['description'] as String?) ?? '',
                  style: MnTypography.body(color: MnColors.inkSoft),
                ),
                const SizedBox(height: 16),
                GlowButton(
                  label: 'Beitreten',
                  variant: GlowVariant.primary,
                  fullWidth: true,
                  onPressed: () {},
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MarketplaceListingScreen extends ConsumerWidget {
  final String listingId;
  const MarketplaceListingScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(_byIdProvider((table: 'marketplace_listings', id: listingId)));
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'MARKTPLATZ'),
      body: SafeArea(
        child: listing.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (l) {
            if (l == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            final price = l['price'];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((l['title'] as String?) ?? '', style: MnTypography.display(size: 24)),
                const SizedBox(height: 8),
                Text(
                  price == null || price == 0
                      ? 'Gratis'
                      : '${price.toString()} EUR',
                  style: MnTypography.mono(size: 28, color: MnColors.amber),
                ),
                const SizedBox(height: 16),
                Text(
                  (l['description'] as String?) ?? '',
                  style: MnTypography.body(color: MnColors.inkSoft),
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: 'Nachricht senden',
                  variant: GlowVariant.primary,
                  fullWidth: true,
                  onPressed: () {},
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ChallengeDetailScreen extends ConsumerWidget {
  final String challengeId;
  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(_byIdProvider((table: 'challenges', id: challengeId)));
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'CHALLENGE'),
      body: SafeArea(
        child: c.when(
          loading: () => const CinemaLoadingSkeleton(),
          error: (e, _) => Center(child: Text('$e', style: MnTypography.body())),
          data: (ch) {
            if (ch == null) return Center(child: Text('Nicht gefunden', style: MnTypography.body()));
            final progress = ((ch['current'] as num?) ?? 0) /
                (((ch['target'] as num?) ?? 1).toDouble());
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text((ch['title'] as String?) ?? '', style: MnTypography.display(size: 24)),
                const SizedBox(height: 8),
                Text(
                  (ch['description'] as String?) ?? '',
                  style: MnTypography.body(color: MnColors.inkSoft),
                ),
                const SizedBox(height: 20),
                Text(
                  '${(progress * 100).round()}% erreicht',
                  style: MnTypography.mono(color: MnColors.amber),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: MnColors.surface,
                  color: MnColors.amber,
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: 'Fortschritt melden',
                  variant: GlowVariant.primary,
                  fullWidth: true,
                  onPressed: () {},
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
