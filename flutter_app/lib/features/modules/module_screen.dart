import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/shadows.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/glow_button.dart';
import '../../core/widgets/kategorie_chip.dart';
import '../../core/widgets/nachbarschaft_card.dart';
import '../../services/supabase/supabase_service.dart';

/// Generisches Modul-Template. Jedes der 13 Module verwendet dieses Widget.
/// - title/icon/accent: Modul-Identitaet im Header
/// - tableName + filter: Datenquelle in Supabase
/// - extraHeader: optionale modulspezifische Widgets (z.B. Saisonkalender)
class ModuleScreen extends ConsumerWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final String tableName;
  final Map<String, Object>? filter;
  final Widget? extraHeader;
  final Widget Function(Map<String, dynamic> row)? itemBuilder;
  final String createRoute;

  const ModuleScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.tableName,
    this.filter,
    this.extraHeader,
    this.itemBuilder,
    this.createRoute = '/posts/new',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_moduleDataProvider(
      _ModuleQuery(tableName: tableName, filter: filter),
    ));

    return CinemaScaffold(
      appBar: CinemaAppBar(title: title.toUpperCase()),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(
              title: title,
              description: description,
              icon: icon,
              accent: accent,
              onCreate: () => GoRouter.of(context).push(createRoute),
            )),
            if (extraHeader != null) SliverToBoxAdapter(child: extraHeader!),
            data.when(
              loading: () => const SliverToBoxAdapter(
                child: CinemaLoadingSkeleton(variant: SkeletonVariant.list),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: CinemaEmptyState(
                  icon: icon,
                  title: 'Fehler',
                  message: e.toString(),
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return SliverToBoxAdapter(
                    child: CinemaEmptyState(
                      icon: icon,
                      title: 'Noch keine Eintraege.',
                      message: 'Sei die*der Erste in deiner Nachbarschaft.',
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    if (itemBuilder != null) return itemBuilder!(rows[i]);
                    return _DefaultPostCard(post: rows[i]);
                  },
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _ModuleQuery {
  final String tableName;
  final Map<String, Object>? filter;
  const _ModuleQuery({required this.tableName, this.filter});

  @override
  bool operator ==(Object other) =>
      other is _ModuleQuery &&
      other.tableName == tableName &&
      _mapEquals(other.filter, filter);

  @override
  int get hashCode => Object.hash(tableName, filter?.length);

  static bool _mapEquals(Map? a, Map? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k] != b[k]) return false;
    }
    return true;
  }
}

final _moduleDataProvider =
    FutureProvider.family<List<Map<String, dynamic>>, _ModuleQuery>((ref, q) async {
  dynamic query = supabase.client
      .from(q.tableName)
      .select(q.tableName == 'posts'
          ? '*, profiles!posts_user_id_fkey(id, full_name, avatar_url)'
          : '*');
  if (q.filter != null) {
    for (final e in q.filter!.entries) {
      query = query.eq(e.key, e.value);
    }
  }
  final res = await query.order('created_at', ascending: false).limit(50);
  return List<Map<String, dynamic>>.from(res as List);
});

class _Header extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final VoidCallback onCreate;

  const _Header({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MnColors.surface,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        boxShadow: MnShadows.coloredGlow(accent, opacity: 0.15),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36, color: accent),
          const SizedBox(height: 12),
          Text(title, style: MnTypography.display(size: 24, color: accent)),
          const SizedBox(height: 4),
          Text(description, style: MnTypography.body(color: MnColors.inkSoft)),
          const SizedBox(height: 16),
          GlowButton(
            label: 'Neuer Beitrag',
            variant: GlowVariant.primary,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _DefaultPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  const _DefaultPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = (post['profiles'] as Map?) ?? const {};
    final kat = PostKategorie.values
        .where((k) => k.name == (post['type'] as String?))
        .firstOrNull;
    return NachbarschaftCard(
      kategorie: kat,
      authorName: author['full_name'] as String?,
      authorAvatarUrl: author['avatar_url'] as String?,
      timeAgo: (post['created_at'] as String?) ?? '',
      content: (post['content'] as String?) ?? '',
      imageUrl: post['image_url'] as String?,
      onTap: () => GoRouter.of(context).push('/posts/${post['id']}'),
    );
  }
}
