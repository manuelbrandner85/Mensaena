/// SKILL: mensaena-features
/// SpotlightSearch (V15) — fullscreen, multi-table live search modal.
///
/// Opens via [SpotlightSearch.showSpotlight]. Runs four queries in parallel
/// (posts / profiles / events / organizations) with a 300 ms debounce and
/// groups the results by category. Tapping a result closes the modal and
/// routes the user to the canonical detail page.
///
/// Cinematic styling:
///   - Pitch-black 80 % scrim
///   - Top-aligned `GlassCard` with amber-glow border + outer bloom
///   - Shimmer rows while the queries are in flight (no spinner)
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import '../effects/glass_card.dart';
import '../effects/shimmer_skeleton.dart';

class SpotlightSearch {
  const SpotlightSearch._();

  /// Presents the spotlight modal over the current route. Returns when the
  /// user closes it.
  static Future<void> showSpotlight(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'search.spotlight'.tr(),
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const _SpotlightOverlay(),
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

enum _ResultKind { post, profile, event, organization }

class _SearchResult {
  const _SearchResult({
    required this.kind,
    required this.id,
    required this.title,
    this.subtitle,
  });

  final _ResultKind kind;
  final String id;
  final String title;
  final String? subtitle;
}

class _SpotlightOverlay extends StatefulWidget {
  const _SpotlightOverlay();

  @override
  State<_SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<_SpotlightOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  String _lastQuery = '';

  final Map<_ResultKind, List<_SearchResult>> _results = {
    _ResultKind.post: [],
    _ResultKind.profile: [],
    _ResultKind.event: [],
    _ResultKind.organization: [],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _loading = false;
        _lastQuery = '';
        for (final k in _results.keys) {
          _results[k] = const [];
        }
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _runQuery(q));
  }

  Future<void> _runQuery(String q) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _lastQuery = q;
    });
    // Escape % and _ to prevent ilike-injection; q itself is plain text.
    final safe = q.replaceAll('%', r'\%').replaceAll('_', r'\_');
    final results = await Future.wait<List<_SearchResult>>([
      _searchPosts(safe),
      _searchProfiles(safe),
      _searchEvents(safe),
      _searchOrganizations(safe),
    ]);
    if (!mounted || _lastQuery != q) return; // stale response
    setState(() {
      _loading = false;
      _results[_ResultKind.post] = results[0];
      _results[_ResultKind.profile] = results[1];
      _results[_ResultKind.event] = results[2];
      _results[_ResultKind.organization] = results[3];
    });
  }

  Future<List<_SearchResult>> _searchPosts(String q) async {
    try {
      final rows = await SupabaseService.client
          .from('posts')
          .select('id,title,description')
          .or('title.ilike.%$q%,description.ilike.%$q%')
          .limit(5);
      return rows.whereType<Map<String, dynamic>>().map((r) {
        return _SearchResult(
          kind: _ResultKind.post,
          id: r['id']?.toString() ?? '',
          title: (r['title'] ?? '—').toString(),
          subtitle: r['description']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Spotlight: posts query failed: $e');
      return const [];
    }
  }

  Future<List<_SearchResult>> _searchProfiles(String q) async {
    try {
      final rows = await SupabaseService.client
          .from('profiles')
          .select('id,name,display_name,username')
          .or(
            'name.ilike.%$q%,display_name.ilike.%$q%,username.ilike.%$q%',
          )
          .limit(5);
      return rows.whereType<Map<String, dynamic>>().map((r) {
        final title = (r['display_name'] ?? r['name'] ?? r['username'] ?? '—')
            .toString();
        return _SearchResult(
          kind: _ResultKind.profile,
          id: r['id']?.toString() ?? '',
          title: title,
          subtitle: r['username']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Spotlight: profiles query failed: $e');
      return const [];
    }
  }

  Future<List<_SearchResult>> _searchEvents(String q) async {
    try {
      final rows = await SupabaseService.client
          .from('events')
          .select('id,title')
          .ilike('title', '%$q%')
          .limit(5);
      return rows.whereType<Map<String, dynamic>>().map((r) {
        return _SearchResult(
          kind: _ResultKind.event,
          id: r['id']?.toString() ?? '',
          title: (r['title'] ?? '—').toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Spotlight: events query failed: $e');
      return const [];
    }
  }

  Future<List<_SearchResult>> _searchOrganizations(String q) async {
    try {
      final rows = await SupabaseService.client
          .from('organizations')
          .select('id,name')
          .ilike('name', '%$q%')
          .limit(5);
      return rows.whereType<Map<String, dynamic>>().map((r) {
        return _SearchResult(
          kind: _ResultKind.organization,
          id: r['id']?.toString() ?? '',
          title: (r['name'] ?? '—').toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Spotlight: organizations query failed: $e');
      return const [];
    }
  }

  void _onTap(_SearchResult r) {
    Navigator.of(context).pop();
    switch (r.kind) {
      case _ResultKind.post:
        context.push('/dashboard/posts/${r.id}');
        break;
      case _ResultKind.profile:
        context.push('/dashboard/profile/${r.id}');
        break;
      case _ResultKind.event:
        context.push('/dashboard/events/${r.id}');
        break;
      case _ResultKind.organization:
        context.push('/dashboard/organizations/${r.id}');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyResult = _results.values.any((l) => l.isNotEmpty);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stop taps inside the card from bubbling up to the dismisser.
              GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: -4,
                      ),
                    ],
                  ),
                  child: GlassCard.strong(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    borderRadius: 16,
                    borderColor: AppColors.amberGlow,
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.search,
                          color: AppColors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            style: AppTypography.body(
                              size: 18,
                              color: AppColors.ink,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isCollapsed: true,
                              hintText: 'search.spotlightHint'.tr(),
                              hintStyle: AppTypography.body(
                                size: 18,
                                color: AppColors.mute,
                              ),
                            ),
                            textInputAction: TextInputAction.search,
                          ),
                        ),
                        if (_controller.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _controller.clear();
                            },
                            child: const Icon(
                              LucideIcons.x,
                              color: AppColors.inkSoft,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    borderRadius: 16,
                    child: _loading
                        ? _buildShimmer()
                        : (hasAnyResult
                            ? _buildResults()
                            : _buildEmpty()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            ShimmerBox(width: 32, height: 32, borderRadius: 8),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(height: 12),
                  SizedBox(height: 6),
                  ShimmerBox(height: 10, width: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final isInitial = _controller.text.trim().isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isInitial ? 'search.empty'.tr() : 'search.noResults'.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.body(size: 13, color: AppColors.mute),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final sections = <Widget>[];
    void addSection(_ResultKind kind, IconData icon, String labelKey) {
      final items = _results[kind] ?? const [];
      if (items.isEmpty) return;
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                labelKey.tr(),
                style: AppTypography.body(
                  size: 11,
                  color: AppColors.inkSoft,
                  weight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      );
      for (final r in items) {
        sections.add(
          InkWell(
            onTap: () => _onTap(r),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            size: 14,
                            color: AppColors.ink,
                            weight: FontWeight.w500,
                          ),
                        ),
                        if (r.subtitle != null && r.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            r.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              size: 12,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.mute,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    addSection(_ResultKind.post, LucideIcons.fileText, 'search.posts');
    addSection(_ResultKind.profile, LucideIcons.user, 'search.profiles');
    addSection(_ResultKind.event, LucideIcons.calendar, 'search.events');
    addSection(
      _ResultKind.organization,
      LucideIcons.building2,
      'search.organizations',
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: sections,
    );
  }
}
