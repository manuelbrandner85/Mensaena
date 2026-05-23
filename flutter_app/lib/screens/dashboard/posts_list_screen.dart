import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../repositories/posts_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/editorial_module_header.dart';
import '../../widgets/shared/empty_state_card.dart';
import '../../widgets/shared/filter_chip_bar.dart';
import '../../widgets/shared/module_search_bar.dart';
import '../../widgets/shared/post_card.dart';

/// SKILL: mensaena-features
/// Posts-Feed — 1:1-Spiegel von `src/app/dashboard/posts/page.tsx`.
/// Features: Suche (Text + Ort), Type-Filter (11), Tag-Filter (9 populaer),
/// Radius-Filter (5/10/25/50/100km mit Geolocation), Aktive-Filter-Strip
/// mit Clear-All, Pagination + Pull-to-Refresh + Empty-State + Reset-CTA.
class PostsListScreen extends ConsumerStatefulWidget {
  const PostsListScreen({super.key});

  @override
  ConsumerState<PostsListScreen> createState() => _PostsListScreenState();
}

class _PostsListScreenState extends ConsumerState<PostsListScreen> {
  // ── Filter-State ────────────────────────────────────────────────────────
  static const List<FilterOption<String>> _typeOptions = [
    FilterOption(value: 'help_request', label: '🆘 Hilfe gesucht'),
    FilterOption(value: 'help_offered', label: '💚 Hilfe'),
    FilterOption(value: 'rescue', label: '🧡 Retten'),
    FilterOption(value: 'animal', label: '🐾 Tier'),
    FilterOption(value: 'housing', label: '🏡 Wohnen'),
    FilterOption(value: 'supply', label: '🌾 Versorgung'),
    FilterOption(value: 'mobility', label: '🚗 Mobilität'),
    FilterOption(value: 'sharing', label: '🔄 Teilen'),
    FilterOption(value: 'community', label: '🗳️ Community'),
    FilterOption(value: 'crisis', label: '🚨 Notfall'),
    FilterOption(value: 'job', label: '💼 Job'),
  ];

  String _search = '';
  String _location = '';
  String? _activeTag;
  String _type = 'all';
  int? _radiusKm;
  double? _userLat;
  double? _userLng;

  // ── Paging ──────────────────────────────────────────────────────────────
  static const int _pageSize = 20;
  List<Post> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;

  // ── Debounce ────────────────────────────────────────────────────────────
  Timer? _searchDebounce;
  Timer? _locationDebounce;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _locationDebounce?.cancel();
    super.dispose();
  }

  Future<void> _ensureLocation() async {
    if (_userLat != null) return;
    try {
      final perm = await Geolocator.checkPermission();
      LocationPermission p = perm;
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('Standort verweigert.',
              style: AppTypography.body(
                  size: 13, color: AppColors.ink)),
        ));
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    } catch (_) {}
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 0;
        _hasMore = true;
        _items = const [];
      });
    } else {
      if (!_hasMore || _loadingMore) return;
      setState(() => _loadingMore = true);
    }
    final combinedQuery = [
      _search.trim(),
      if (_activeTag != null) _activeTag!.replaceFirst('#', ''),
    ].where((s) => s.isNotEmpty).join(' ');
    final useRadius = _radiusKm != null && _userLat != null;
    final fetched = await PostsRepository.search(
      query: combinedQuery,
      type: _type,
      lat: useRadius ? _userLat : null,
      lng: useRadius ? _userLng : null,
      radiusKm: _radiusKm ?? 50,
      limit: _pageSize,
      offset: _page * _pageSize,
    );
    // Client-side location-text-Filter (wie Web Z. 148-152).
    final filtered = _location.trim().isEmpty
        ? fetched
        : fetched
            .where((p) => (p.locationText ?? '')
                .toLowerCase()
                .contains(_location.toLowerCase()))
            .toList();
    if (!mounted) return;
    setState(() {
      if (reset) {
        _items = filtered;
      } else {
        _items = [..._items, ...filtered];
      }
      _hasMore = fetched.length == _pageSize;
      _page += 1;
      _loading = false;
      _loadingMore = false;
    });
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _search = v;
      _load(reset: true);
    });
  }

  void _onLocationChanged(String v) {
    _locationDebounce?.cancel();
    _locationDebounce = Timer(const Duration(milliseconds: 350), () {
      _location = v;
      _load(reset: true);
    });
  }

  void _resetAll() {
    setState(() {
      _search = '';
      _location = '';
      _activeTag = null;
      _type = 'all';
      _radiusKm = null;
    });
    _load(reset: true);
  }

  void _toggleTag(String tag) {
    setState(() {
      _activeTag = _activeTag == tag ? null : tag;
    });
    _load(reset: true);
  }

  Future<void> _toggleRadius(int km) async {
    if (_userLat == null) {
      await _ensureLocation();
      if (_userLat == null) return;
    }
    setState(() {
      _radiusKm = _radiusKm == km ? null : km;
    });
    _load(reset: true);
  }

  bool get _hasActiveFilters =>
      _search.isNotEmpty ||
      _location.isNotEmpty ||
      _activeTag != null ||
      _type != 'all' ||
      _radiusKm != null;

  List<ActiveFilterChip> get _activeChips {
    final out = <ActiveFilterChip>[];
    if (_type != 'all') {
      final opt =
          _typeOptions.firstWhere((o) => o.value == _type, orElse: () => _typeOptions.first);
      out.add(ActiveFilterChip(
        label: opt.label,
        onRemove: () {
          setState(() => _type = 'all');
          _load(reset: true);
        },
      ));
    }
    if (_activeTag != null) {
      out.add(ActiveFilterChip(
        label: _activeTag!,
        onRemove: () {
          setState(() => _activeTag = null);
          _load(reset: true);
        },
      ));
    }
    if (_radiusKm != null) {
      out.add(ActiveFilterChip(
        label: '📡 $_radiusKm km',
        onRemove: () {
          setState(() => _radiusKm = null);
          _load(reset: true);
        },
      ));
    }
    if (_location.isNotEmpty) {
      out.add(ActiveFilterChip(
        label: '📍 $_location',
        onRemove: () {
          _location = '';
          _load(reset: true);
        },
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Beiträge',
      currentRoute: '/dashboard/posts',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/create'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Posten'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Editorial-Header (1:1 Web) ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 05',
                metaCategory: 'Beiträge',
                title: 'Alle Beiträge',
                subtitle: _loading
                    ? 'Lade Beiträge in deiner Nähe…'
                    : '${_items.length}${_hasMore ? "+" : ""} aktiv in deiner Nähe',
              ),
            ),
            // ── Search + Filter-Sheet ────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: ModuleSearchBar(
                hintText: 'Beiträge durchsuchen…',
                initialValue: _search,
                onChanged: _onSearchChanged,
                onFilterTap: () => _openFilterSheet(context),
                showFilterDot: _hasActiveFilters,
              ),
            ),
            // ── Type-Filter-Pills ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: FilterChipBar<String>(
                options: _typeOptions,
                selected: _type == 'all' ? const <String>{} : {_type},
                onChanged: (s) {
                  setState(() => _type = s.isEmpty ? 'all' : s.first);
                  _load(reset: true);
                },
              ),
            ),
            // ── Tag-Filter (Popular) ─────────────────────────────
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final tag in kPopularPostTags) ...[
                    _TagChip(
                      tag: tag,
                      active: _activeTag == tag,
                      onTap: () => _toggleTag(tag),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            // ── Active-Filter-Strip ──────────────────────────────
            if (_activeChips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ActiveFilterStrip(
                  chips: _activeChips,
                  onClearAll: _resetAll,
                ),
              ),
            // ── List ─────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: () => _load(reset: true),
                child: _buildList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 110,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.4),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 60),
          EmptyStateCard(
            icon: LucideIcons.inbox,
            title: _hasActiveFilters
                ? 'Keine Treffer für die Filter.'
                : 'Noch keine Beiträge.',
            description: _hasActiveFilters
                ? 'Setze Filter zurück oder verändere deine Suche.'
                : 'Sei der/die Erste:r — tippe den Plus-Button.',
            actionLabel: _hasActiveFilters ? 'Filter zurücksetzen' : null,
            onAction: _hasActiveFilters ? _resetAll : null,
          ),
        ],
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 240) {
          _load();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator(
                        color: AppColors.amber)
                    : TextButton(
                        onPressed: () => _load(),
                        child: Text('Mehr laden',
                            style: AppTypography.label(
                              size: 10,
                              color: AppColors.amber,
                            )),
                      ),
              ),
            );
          }
          return PostCard(post: _items[i]);
        },
      ),
    );
  }

  // ── Filter-Bottom-Sheet (Location + Radius) ─────────────────────────
  void _openFilterSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Erweiterte Filter',
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink)),
              const SizedBox(height: 14),
              Text('Ort', style: AppTypography.label(size: 10)),
              const SizedBox(height: 6),
              TextField(
                controller:
                    TextEditingController(text: _location)..selection =
                        TextSelection.collapsed(offset: _location.length),
                onChanged: _onLocationChanged,
                style: AppTypography.body(
                    size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.elevated,
                  prefixIcon: const Icon(LucideIcons.mapPin,
                      size: 14, color: AppColors.mute),
                  hintText: 'z.B. Wien, 1010, Graz…',
                  hintStyle: AppTypography.body(
                      size: 13, color: AppColors.mute),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Umkreis', style: AppTypography.label(size: 10)),
                  const Spacer(),
                  if (_userLat == null)
                    TextButton.icon(
                      onPressed: () async {
                        await _ensureLocation();
                        setSheet(() {});
                      },
                      icon: const Icon(LucideIcons.locate,
                          size: 12, color: AppColors.amber),
                      label: Text('Standort verwenden',
                          style: AppTypography.label(
                              size: 9, color: AppColors.amber)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final km in kRadiusPresetsKm)
                    GestureDetector(
                      onTap: () async {
                        await _toggleRadius(km);
                        setSheet(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _radiusKm == km
                              ? AppColors.amber.withValues(alpha: 0.18)
                              : AppColors.elevated,
                          border: Border.all(
                            color: _radiusKm == km
                                ? AppColors.amber.withValues(alpha: 0.6)
                                : AppColors.line,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$km km',
                            style: AppTypography.label(
                              size: 10,
                              color: _radiusKm == km
                                  ? AppColors.amber
                                  : AppColors.inkSoft,
                            )),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.inkSoft,
                        side: const BorderSide(color: AppColors.line),
                      ),
                      onPressed: () {
                        _resetAll();
                        Navigator.pop(sheetCtx);
                      },
                      child: const Text('Zurücksetzen'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: AppColors.voidColor,
                      ),
                      onPressed: () => Navigator.pop(sheetCtx),
                      child: const Text('Übernehmen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.active,
    required this.onTap,
  });

  final String tag;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.teal.withValues(alpha: 0.18)
              : AppColors.elevated,
          border: Border.all(
            color: active
                ? AppColors.tealSoft.withValues(alpha: 0.6)
                : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          tag,
          style: AppTypography.mono(
            size: 11,
            color: active ? AppColors.tealSoft : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
