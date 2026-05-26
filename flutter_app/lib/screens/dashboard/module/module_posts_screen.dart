import 'package:easy_localization/easy_localization.dart';
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
class ModuleQuickAction {
  const ModuleQuickAction({
    required this.icon,
    required this.label,
    required this.route,
    this.color,
  });
  final IconData icon;
  final String label;
  final String route;
  final Color? color;
}

class ModulePostsScreen extends ConsumerStatefulWidget {
  const ModulePostsScreen({
    required this.title,
    required this.emoji,
    required this.postType,
    required this.route,
    this.subtitle,
    this.subFilters = const [],
    this.quickActions = const [],
    this.moduleKey,
    super.key,
  });

  final String title;
  final String emoji;
  final String postType;
  /// Optional: zusaetzlich nach posts.module_key filtern (Versorgung/Harvest
  /// erstellt Posts mit type=sharing|community|rescue + module_key=harvest).
  /// Wenn gesetzt, wird OR-Filter type=X OR module_key=Y verwendet.
  final String? moduleKey;
  final String route;
  final String? subtitle;
  final List<FilterOption<String>> subFilters;

  /// Feature-Buttons direkt unter dem Header — z.B. "Tier bestimmen"
  /// fuer Animals oder "Wildfruechte" fuer Harvest. Tap → context.go(route).
  final List<ModuleQuickAction> quickActions;

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
      // BUG-FIX (User-Report: "in rettung sind falsche Postings"):
      // Vorher: OR-Filter (type=X ODER module_key=Y) → matched ALLE
      // type=sharing-Posts global, also auch nicht für harvest gemeinte
      // → harvest-Modul zeigte fremde Posts.
      //
      // Jetzt: moduleKey gesetzt → STRIKT module_key=Y (Module-Wizard
      // setzt das immer). Backwards-compat für alte Posts ohne module_key:
      // type=X UND module_key IS NULL erlaubt.
      var q = sb.from('posts').select().eq('status', 'active');
      if (widget.moduleKey != null) {
        q = q.or(
            'module_key.eq.${widget.moduleKey},and(type.eq.${widget.postType},module_key.is.null)');
      } else {
        q = q.eq('type', widget.postType);
      }
      final rows = await q
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
          // FIX (User-Wunsch): push statt go damit Zurück-Button vom
          // Create-Screen ZURÜCK ins Modul führt statt komplett zum
          // Dashboard.
          final moduleRoute = _moduleCreateRouteFor(widget.postType);
          context.push(moduleRoute);
        },
        icon: const Icon(LucideIcons.plus),
        label: Text('modules.post'.tr()),
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
            if (widget.quickActions.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    for (final a in widget.quickActions) ...[
                      _QuickActionChip(action: a),
                      const SizedBox(width: 8),
                    ],
                  ],
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

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({required this.action});
  final ModuleQuickAction action;

  @override
  Widget build(BuildContext context) {
    final c = action.color ?? AppColors.bronze;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => context.push(action.route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          border: Border.all(color: c.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 14, color: c),
            const SizedBox(width: 6),
            Text(action.label.tr(),
                style: AppTypography.label(size: 11, color: c)),
          ],
        ),
      ),
    );
  }
}
