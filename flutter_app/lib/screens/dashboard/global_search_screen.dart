import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/skeleton_card.dart';

/// SKILL: mensaena-features
/// Global-Search — aggregiert Posts + Profile + Events + Organisationen.
/// 1:1 zu Web /search → CommandPalette + /dashboard/posts?q=
class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<GlobalSearchScreen> createState() =>
      _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';
  Future<_SearchResults>? _future;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery ?? '';
    _ctrl.text = q;
    _query = q;
    if (q.length >= 2) _future = _runSearch(q);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<_SearchResults> _runSearch(String q) async {
    final query = q.trim();
    if (query.length < 2) return const _SearchResults.empty();
    try {
      // Parallel fetch via 4 endpoints — 1:1 zu Web CommandPalette
      final results = await Future.wait<List<dynamic>>([
        // Posts via search_posts RPC (fallback to ilike if RPC missing)
        _searchPosts(query),
        // Profiles direct query
        sb
            .from('profiles')
            .select('id, name, display_name, nickname, avatar_url, location')
            .or('name.ilike.%$query%,nickname.ilike.%$query%,display_name.ilike.%$query%')
            .limit(10),
        // Events
        sb
            .from('events')
            .select('id, title, description, start_date, location_name')
            .ilike('title', '%$query%')
            .eq('status', 'active')
            .order('start_date')
            .limit(10),
        // Organizations
        sb
            .from('organizations')
            .select('id, name, category, city, is_verified')
            .or('name.ilike.%$query%,description.ilike.%$query%')
            .limit(10),
      ]);
      return _SearchResults(
        posts: results[0].whereType<Map<String, dynamic>>().toList(),
        profiles: results[1].whereType<Map<String, dynamic>>().toList(),
        events: results[2].whereType<Map<String, dynamic>>().toList(),
        organizations:
            results[3].whereType<Map<String, dynamic>>().toList(),
      );
    } catch (_) {
      return const _SearchResults.empty();
    }
  }

  Future<List<Map<String, dynamic>>> _searchPosts(String q) async {
    try {
      final res = await sb.rpc<dynamic>('search_posts', params: {
        'p_query': q,
        'p_limit': 10,
      });
      if (res is List) {
        return res.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    // Fallback: direct ilike
    try {
      final res = await sb
          .from('posts')
          .select('id, title, type, description, created_at')
          .or('title.ilike.%$q%,description.ilike.%$q%')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10);
      return (res as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  void _onChanged(String v) {
    setState(() {
      _query = v;
      _future = v.trim().length >= 2 ? _runSearch(v) : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'search.title'.tr(),
      currentRoute: '/dashboard/search',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                style: AppTypography.body(size: 15, color: AppColors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.elevated,
                  prefixIcon: const Icon(LucideIcons.search,
                      size: 18, color: AppColors.mute),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x,
                              size: 16, color: AppColors.mute),
                          onPressed: () {
                            _ctrl.clear();
                            _onChanged('');
                          },
                        )
                      : null,
                  hintText: 'search.hintPostsProfilesEvents'.tr(),
                  hintStyle: AppTypography.body(
                      size: 14, color: AppColors.mute),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _query.trim().length < 2
                  ? _EmptyHint()
                  : FutureBuilder<_SearchResults>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const SkeletonList(
                              count: 5, itemHeight: 70);
                        }
                        final r = snap.data ?? const _SearchResults.empty();
                        if (r.isEmpty) return _NoResults(query: _query);
                        return ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (r.posts.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'Beiträge', count: r.posts.length),
                              for (final p in r.posts)
                                _ResultTile(
                                  icon: LucideIcons.fileText,
                                  color: AppColors.bronze,
                                  title: (p['title'] as String?) ?? '',
                                  subtitle: (p['type'] as String?) ?? '',
                                  onTap: () => context
                                      .go('/dashboard/posts/${p['id']}'),
                                ),
                            ],
                            if (r.profiles.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'Nachbar:innen',
                                  count: r.profiles.length),
                              for (final p in r.profiles)
                                _ResultTile(
                                  icon: LucideIcons.user,
                                  color: AppColors.amber,
                                  title: (p['display_name'] as String?) ??
                                      (p['name'] as String?) ??
                                      'Nachbar:in',
                                  subtitle: (p['nickname'] as String?) !=
                                          null
                                      ? '@${p['nickname']}'
                                      : (p['location'] as String?) ?? '',
                                  onTap: () => context.go(
                                      '/dashboard/profile/${p['id']}'),
                                ),
                            ],
                            if (r.events.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'Events', count: r.events.length),
                              for (final e in r.events)
                                _ResultTile(
                                  icon: LucideIcons.calendar,
                                  color: AppColors.tealSoft,
                                  title: (e['title'] as String?) ?? '',
                                  subtitle:
                                      (e['location_name'] as String?) ?? '',
                                  onTap: () => context
                                      .go('/dashboard/events/${e['id']}'),
                                ),
                            ],
                            if (r.organizations.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'Organisationen',
                                  count: r.organizations.length),
                              for (final o in r.organizations)
                                _ResultTile(
                                  icon: LucideIcons.building2,
                                  color: AppColors.lebenSoft,
                                  title: (o['name'] as String?) ?? '',
                                  subtitle: [
                                    o['category'],
                                    o['city'],
                                    if (o['is_verified'] == true)
                                      '✓ Verifiziert',
                                  ]
                                      .whereType<String>()
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  onTap: () => context.go(
                                      '/dashboard/organizations/${o['id']}'),
                                ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults {
  const _SearchResults({
    required this.posts,
    required this.profiles,
    required this.events,
    required this.organizations,
  });
  const _SearchResults.empty()
      : posts = const [],
        profiles = const [],
        events = const [],
        organizations = const [];

  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> organizations;

  bool get isEmpty =>
      posts.isEmpty &&
      profiles.isEmpty &&
      events.isEmpty &&
      organizations.isEmpty;
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.search, size: 32, color: AppColors.mute),
          const SizedBox(height: 10),
          Text('search.minChars'.tr(),
              style:
                  AppTypography.body(size: 13, color: AppColors.mute)),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.searchX, size: 32, color: AppColors.mute),
          const SizedBox(height: 10),
          Text('search.noResultsForQuery'.tr(namedArgs: {'query': query}),
              style:
                  AppTypography.body(size: 14, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text('search.tryOther'.tr(),
              style:
                  AppTypography.body(size: 12, color: AppColors.mute)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        children: [
          Text(label.toUpperCase(),
              style:
                  AppTypography.label(size: 10, color: AppColors.mute)),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count',
                style: AppTypography.mono(
                    size: 9, color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w600)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                            size: 11, color: AppColors.mute)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 14, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}
