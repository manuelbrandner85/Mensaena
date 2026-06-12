import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/skeleton_card.dart';
import '../../repositories/search_repository.dart';
import 'modules_hub_screen.dart' show ModuleTile, kModulesCatalog;

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
  Timer? _debounce;
  List<String> _recent = const [];

  static const _storage = FlutterSecureStorage();
  static const _recentKey = 'mensaena_recent_searches_v1';
  static const _maxRecent = 6;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery ?? '';
    _ctrl.text = q;
    _query = q;
    if (q.length >= 2) _future = _runSearch(q);
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Lokale, synchrone Modul-Suche über kModulesCatalog. So findet ein
  /// Nutzer "Tiere", "Wohnen", "Karte" usw. direkt als Modul-Treffer und
  /// nicht nur als Inhalts-Treffer in Posts/Profilen. Case-insensitive,
  /// matched gegen die übersetzte Label-Anzeige.
  List<ModuleTile> _matchModules(String q) {
    final needle = q.trim().toLowerCase();
    if (needle.length < 2) return const [];
    return [
      for (final m in kModulesCatalog)
        if (m.label.tr().toLowerCase().contains(needle)) m,
    ];
  }

  Future<_SearchResults> _runSearch(String q) async {
    final query = q.trim();
    if (query.length < 2) return const _SearchResults.empty();
    final pattern = '%$query%';
    try {
      // 8 Parallel-Quellen für die globale Suche — alle im
      // SearchRepository (8s-Timeout + Fail-Safe pro Quelle, damit eine
      // fehlende Tabelle/RLS nicht die anderen 7 Ergebnisse killt).
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _searchPosts(query),
        SearchRepository.profiles(pattern),
        SearchRepository.events(pattern),
        SearchRepository.organizations(pattern),
        SearchRepository.groups(pattern),
        SearchRepository.marketplace(pattern),
        SearchRepository.boardPosts(pattern),
        SearchRepository.knowledge(pattern),
      ]);
      return _SearchResults(
        modules: _matchModules(query),
        posts: results[0],
        profiles: results[1],
        events: results[2],
        organizations: results[3],
        groups: results[4],
        marketplace: results[5],
        board: results[6],
        knowledge: results[7],
      );
    } catch (_) {
      // Auch bei DB-Fehlern wenigstens die Module-Treffer zeigen — die sind
      // rein lokal und immer verfügbar.
      return _SearchResults(
        modules: _matchModules(query),
        posts: const [],
        profiles: const [],
        events: const [],
        organizations: const [],
        groups: const [],
        marketplace: const [],
        board: const [],
        knowledge: const [],
      );
    }
  }

  // ── Recent-Searches: persistiert via SecureStorage, max 6 Einträge ──
  Future<void> _loadRecent() async {
    try {
      final raw = await _storage.read(key: _recentKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      if (!mounted) return;
      setState(() => _recent =
          decoded.whereType<String>().toList(growable: false));
    } catch (_) {/* default leer */}
  }

  Future<void> _pushRecent(String q) async {
    final trimmed = q.trim();
    if (trimmed.length < 2) return;
    final list = List<String>.from(_recent);
    list.removeWhere((s) => s.toLowerCase() == trimmed.toLowerCase());
    list.insert(0, trimmed);
    while (list.length > _maxRecent) {
      list.removeLast();
    }
    setState(() => _recent = list);
    try {
      await _storage.write(key: _recentKey, value: jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const []);
    try {
      await _storage.delete(key: _recentKey);
    } catch (_) {}
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
    return SearchRepository.postsFallback(q);
  }

  void _onChanged(String v) {
    // Sofort _query setzen (UI/Clear-Button reagiert), aber die DB-Suche
    // erst nach 300ms Ruhe auslösen (Debounce statt Query pro Tastendruck).
    setState(() => _query = v);
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() => _future = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _future = _runSearch(v));
      _pushRecent(v);
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
                        tooltip: 'common.close'.tr(),
                          icon: const Icon(LucideIcons.x,
                              size: 16, color: AppColors.mute),
                          onPressed: () {
                            _ctrl.clear();
                            _onChanged('');
                          },
                        )
                      : null,
                  hintText: 'search.hintAllSources'.tr(),
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
                  ? _RecentPanel(
                      recent: _recent,
                      onPick: (q) {
                        _ctrl.text = q;
                        _onChanged(q);
                      },
                      onClear: _clearRecent,
                    )
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
                            // Module-Direkt-Treffer GANZ OBEN: ein Tap
                            // bringt den User direkt zum Modul (z.B. "Tier"
                            // → Tiere-Modul). Ohne diese Sektion findet die
                            // Suche nur Inhalte, nicht die Modul-Einstiege.
                            if (r.modules.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'search.modules'.tr(),
                                  count: r.modules.length),
                              for (final m in r.modules)
                                _ResultTile(
                                  icon: m.icon,
                                  color: m.tint,
                                  title: m.label.tr(),
                                  subtitle: m.section.tr(),
                                  onTap: () {
                                    _pushRecent(_query);
                                    context.go(m.route);
                                  },
                                ),
                            ],
                            if (r.posts.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'search.posts'.tr(),
                                  count: r.posts.length),
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
                                  label: 'search.profiles'.tr(),
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
                                  label: 'search.events'.tr(),
                                  count: r.events.length),
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
                            if (r.groups.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'search.groups'.tr(),
                                  count: r.groups.length),
                              for (final g in r.groups)
                                _ResultTile(
                                  icon: LucideIcons.users2,
                                  color: AppColors.teal,
                                  title: (g['name'] as String?) ?? '',
                                  subtitle: [
                                    g['category'],
                                    if ((g['member_count'] as num? ?? 0) > 0)
                                      '${g['member_count']} 👥',
                                  ]
                                      .whereType<String>()
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  onTap: () => context
                                      .go('/dashboard/groups/${g['id']}'),
                                ),
                            ],
                            if (r.marketplace.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'search.marketplace'.tr(),
                                  count: r.marketplace.length),
                              for (final m in r.marketplace)
                                _ResultTile(
                                  icon: LucideIcons.shoppingBag,
                                  color: AppColors.amber,
                                  title: (m['title'] as String?) ?? '',
                                  subtitle: [
                                    m['listing_type'],
                                    if (m['price'] != null)
                                      '${m['price']} €',
                                    m['location_text'],
                                  ]
                                      .whereType<Object>()
                                      .map((o) => '$o')
                                      .where((s) => s.isNotEmpty)
                                      .join(' · '),
                                  onTap: () => context.go(
                                      '/dashboard/marketplace/${m['id']}'),
                                ),
                            ],
                            if (r.board.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'search.board'.tr(),
                                  count: r.board.length),
                              for (final b in r.board)
                                _ResultTile(
                                  icon: LucideIcons.stickyNote,
                                  color: AppColors.bronze,
                                  title: (b['content'] as String?) ?? '',
                                  subtitle:
                                      (b['category'] as String?) ?? '',
                                  onTap: () => context
                                      .go('/dashboard/board/${b['id']}'),
                                ),
                            ],
                            if (r.knowledge.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'search.knowledge'.tr(),
                                  count: r.knowledge.length),
                              for (final k in r.knowledge)
                                _ResultTile(
                                  icon: LucideIcons.bookOpen,
                                  color: AppColors.lebenSoft,
                                  title: (k['title'] as String?) ?? '',
                                  subtitle: (k['summary'] as String?) ??
                                      (k['category'] as String?) ??
                                      '',
                                  onTap: () => context.go(
                                      '/dashboard/knowledge/${k['slug'] ?? k['id']}'),
                                ),
                            ],
                            if (r.organizations.isNotEmpty) ...[
                              _SectionHeader(
                                  label: 'search.organizations'.tr(),
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
    required this.modules,
    required this.posts,
    required this.profiles,
    required this.events,
    required this.organizations,
    required this.groups,
    required this.marketplace,
    required this.board,
    required this.knowledge,
  });
  const _SearchResults.empty()
      : modules = const [],
        posts = const [],
        profiles = const [],
        events = const [],
        organizations = const [],
        groups = const [],
        marketplace = const [],
        board = const [],
        knowledge = const [];

  // Modul-Direkt-Treffer aus kModulesCatalog — wird OBEN angezeigt, damit
  // ein User der "Tier" tippt sofort zum Tiere-Modul springen kann.
  final List<ModuleTile> modules;
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> organizations;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> marketplace;
  final List<Map<String, dynamic>> board;
  final List<Map<String, dynamic>> knowledge;

  bool get isEmpty =>
      modules.isEmpty &&
      posts.isEmpty &&
      profiles.isEmpty &&
      events.isEmpty &&
      organizations.isEmpty &&
      groups.isEmpty &&
      marketplace.isEmpty &&
      board.isEmpty &&
      knowledge.isEmpty;
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

/// Recent-Searches-Panel: zeigt zuletzt gesuchte Begriffe als Chips, wenn
/// die Eingabe leer ist. Tap auf einen Chip → erneute Suche. Persistent in
/// SecureStorage.
class _RecentPanel extends StatelessWidget {
  const _RecentPanel({
    required this.recent,
    required this.onPick,
    required this.onClear,
  });

  final List<String> recent;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) return _EmptyHint();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'search.recentTitle'.tr().toUpperCase(),
                style: AppTypography.label(size: 10, color: AppColors.mute),
              ),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(LucideIcons.trash2, size: 12),
              label: Text('search.recentClear'.tr()),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.mute,
                textStyle: AppTypography.label(size: 10),
                minimumSize: const Size(0, 28),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in recent)
              GestureDetector(
                onTap: () => onPick(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.elevated.withValues(alpha: 0.6),
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.clock,
                          size: 12, color: AppColors.mute),
                      const SizedBox(width: 6),
                      Text(q,
                          style: AppTypography.body(
                              size: 13, color: AppColors.ink)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
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
