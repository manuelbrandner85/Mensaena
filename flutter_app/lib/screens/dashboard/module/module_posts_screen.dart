import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/post.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/module_search_bar.dart';
import '../../../widgets/shared/post_card.dart';

/// SKILL: mensaena-features
/// Generischer Modul-Screen — 1:1 zu `src/components/shared/ModulePage.tsx`.
/// Filtert posts nach Type. Pro Modul: Title, Emoji, Subtitle, PostType,
/// optionale Sub-Filter-Pills (z.B. animals: lost/found/care).
class ModulePostsScreen extends ConsumerStatefulWidget {
  const ModulePostsScreen({
    required this.title,
    required this.emoji,
    required this.postType,
    required this.route,
    this.subtitle,
    this.subFilters = const [],
    super.key,
  });

  final String title;
  final String emoji;
  final String postType;
  final String route;
  final String? subtitle;
  final List<FilterOption<String>> subFilters;

  @override
  ConsumerState<ModulePostsScreen> createState() => _ModulePostsScreenState();
}

class _ModulePostsScreenState extends ConsumerState<ModulePostsScreen> {
  Future<List<Post>>? _future;
  String _search = '';
  String? _subFilter;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Post>> _load() async {
    try {
      final rows = await sb
          .from('posts')
          .select()
          .eq('type', widget.postType)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(100);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  bool get _hasFilters => _search.isNotEmpty || _subFilter != null;

  List<Post> _apply(List<Post> all) {
    final q = _search.trim().toLowerCase();
    return all.where((p) {
      if (_subFilter != null && p.category != _subFilter) return false;
      if (q.isEmpty) return true;
      return p.title.toLowerCase().contains(q) ||
          (p.description ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: widget.title,
      currentRoute: widget.route,
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () {
          // 1:1 Web: Modul-spezifische Create-Route mit Whitelist
          // statt generischem /dashboard/create?type=
          final moduleRoute = _moduleCreateRouteFor(widget.postType);
          context.go(moduleRoute);
        },
        icon: const Icon(LucideIcons.plus),
        label: const Text('Beitrag'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(widget.emoji,
                        style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: AppTypography.display(
                                size: 22, color: AppColors.ink)),
                        if (widget.subtitle != null)
                          Text(widget.subtitle!,
                              style: AppTypography.caption()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: ModuleSearchBar(
                hintText: '${widget.title} durchsuchen…',
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            if (widget.subFilters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: FilterChipBar<String>(
                  options: widget.subFilters,
                  selected:
                      _subFilter == null ? const <String>{} : {_subFilter!},
                  onChanged: (s) => setState(
                      () => _subFilter = s.isEmpty ? null : s.first),
                ),
              ),
            if (_hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ActiveFilterStrip(
                  chips: [
                    if (_subFilter != null)
                      ActiveFilterChip(
                        label: widget.subFilters
                            .firstWhere((o) => o.value == _subFilter)
                            .label,
                        onRemove: () => setState(() => _subFilter = null),
                      ),
                    if (_search.isNotEmpty)
                      ActiveFilterChip(
                        label: '🔍 $_search',
                        onRemove: () => setState(() => _search = ''),
                      ),
                  ],
                  onClearAll: () => setState(() {
                    _search = '';
                    _subFilter = null;
                  }),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: _refresh,
                child: FutureBuilder<List<Post>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.amber),
                      );
                    }
                    final list = _apply(snap.data ?? const <Post>[]);
                    if (list.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 40),
                          EmptyStateCard(
                            icon: LucideIcons.inbox,
                            title: _hasFilters
                                ? 'Keine Treffer.'
                                : 'Noch keine ${widget.title}-Beiträge.',
                            description: _hasFilters
                                ? 'Andere Filter probieren.'
                                : 'Sei der/die Erste:r — Plus-Button.',
                            actionLabel:
                                _hasFilters ? 'Filter zurücksetzen' : null,
                            onAction: _hasFilters
                                ? () => setState(() {
                                      _search = '';
                                      _subFilter = null;
                                    })
                                : null,
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, i) => PostCard(post: list[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mappt den postType auf die Modul-Create-Route. Siehe ModuleCreateConfig
/// fuer die 1:1-Web-Parity-Whitelist-Pages.
String _moduleCreateRouteFor(String postType) {
  switch (postType) {
    case 'animal':
      return '/dashboard/animals/create';
    case 'housing':
      return '/dashboard/housing/create';
    case 'mobility':
      return '/dashboard/mobility/create';
    case 'sharing':
      return '/dashboard/sharing/create';
    case 'supply': // harvest verwendet supply als Post-Type
      return '/dashboard/harvest/create';
    case 'community':
      return '/dashboard/community/create';
    case 'rescue':
      return '/dashboard/rescuer/create';
    case 'job':
      return '/dashboard/jobs/create';
    default:
      return '/dashboard/create?type=$postType';
  }
}
