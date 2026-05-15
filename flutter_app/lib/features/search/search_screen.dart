import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_avatar.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_tabs.dart';
import '../../core/widgets/nachbarschaft_card.dart';
import '../../services/supabase/supabase_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';

  List<Map<String, dynamic>> _posts = const [];
  List<Map<String, dynamic>> _people = const [];
  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _wiki = const [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(v));
  }

  Future<void> _run(String q) async {
    setState(() {
      _q = q.trim();
      _loading = true;
    });
    if (_q.isEmpty) {
      setState(() {
        _posts = const [];
        _people = const [];
        _groups = const [];
        _events = const [];
        _wiki = const [];
        _loading = false;
      });
      return;
    }
    final term = '%$_q%';
    try {
      final results = await Future.wait([
        supabase.client
            .from('posts')
            .select(
              'id, type, content, created_at, profiles!inner(id, full_name, avatar_url)',
            )
            .ilike('content', term)
            .order('created_at', ascending: false)
            .limit(20),
        supabase.client
            .from('profiles')
            .select('id, full_name, avatar_url, location')
            .ilike('full_name', term)
            .limit(20),
        supabase.client
            .from('groups')
            .select('id, name, description')
            .ilike('name', term)
            .limit(20),
        supabase.client
            .from('events')
            .select('id, title, starts_at, location')
            .ilike('title', term)
            .limit(20),
        supabase.client
            .from('knowledge_articles')
            .select('id, title, content')
            .ilike('title', term)
            .limit(20),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = List<Map<String, dynamic>>.from(results[0] as List);
        _people = List<Map<String, dynamic>>.from(results[1] as List);
        _groups = List<Map<String, dynamic>>.from(results[2] as List);
        _events = List<Map<String, dynamic>>.from(results[3] as List);
        _wiki = List<Map<String, dynamic>>.from(results[4] as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Hebt jedes Vorkommen von `q` im Text mit Amber + Bold hervor.
  List<TextSpan> _highlight(
    String text,
    String q, {
    TextStyle? base,
  }) {
    final baseStyle = base ?? MnTypography.body(color: MnColors.ink);
    if (q.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    final lower = text.toLowerCase();
    final needle = q.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      final idx = lower.indexOf(needle, i);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(i), style: baseStyle));
        break;
      }
      if (idx > i) {
        spans.add(TextSpan(text: text.substring(i, idx), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + needle.length),
          style: baseStyle.copyWith(
            color: MnColors.amber,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      i = idx + needle.length;
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'SUCHE'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CinemaInput(
                controller: _ctrl,
                placeholder: 'Nachbarschaft durchsuchen...',
                variant: CinemaInputVariant.search,
                autofocus: true,
                onChanged: _onQuery,
              ),
            ),
            CinemaTabs(
              controller: _tabs,
              labels: const ['Beitraege', 'Personen', 'Gruppen', 'Events', 'Wiki'],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _postsList(),
                  _peopleList(),
                  _groupsList(),
                  _eventsList(),
                  _wikiList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String label) => CinemaEmptyState(
        icon: LucideIcons.search,
        title: _q.isEmpty ? 'Tippe einen Suchbegriff ein.' : 'Keine Treffer fuer "$_q".',
        message: label,
      );

  Widget _loadingOr(Widget Function() body, List<Map<String, dynamic>> data, String emptyLabel) {
    if (_loading && _q.isNotEmpty) {
      return const Center(child: CircularProgressIndicator(color: MnColors.amber));
    }
    if (_q.isEmpty || data.isEmpty) return _empty(emptyLabel);
    return body();
  }

  // ── POSTS ─────────────────────────────────────────────────────────────
  Widget _postsList() => _loadingOr(
        () => ListView.builder(
          itemCount: _posts.length,
          itemBuilder: (_, i) {
            final p = _posts[i];
            final author = (p['profiles'] as Map<String, dynamic>?) ??
                const <String, dynamic>{};
            final content = (p['content'] as String?) ?? '';
            return GestureDetector(
              onTap: () => GoRouter.of(context).push('/posts/${p['id']}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MnColors.surface,
                    borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                    border: Border.all(color: MnColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (author['full_name'] as String?) ?? 'Nachbar*in',
                        style: MnTypography.label(color: MnColors.amber),
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(children: _highlight(content, _q)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        _posts,
        'Beitraege folgen.',
      );

  // ── PEOPLE ────────────────────────────────────────────────────────────
  Widget _peopleList() => _loadingOr(
        () => ListView.builder(
          itemCount: _people.length,
          itemBuilder: (_, i) {
            final p = _people[i];
            final name = (p['full_name'] as String?) ?? 'Nachbar*in';
            return ListTile(
              leading: CinemaAvatar(
                imageUrl: p['avatar_url'] as String?,
                displayName: name,
              ),
              title: RichText(
                text: TextSpan(children: _highlight(name, _q)),
              ),
              subtitle: Text(
                (p['location'] as String?) ?? '',
                style: MnTypography.caption(),
              ),
              onTap: () => GoRouter.of(context).push('/profile/${p['id']}'),
            );
          },
        ),
        _people,
        'Personen folgen.',
      );

  // ── GROUPS ────────────────────────────────────────────────────────────
  Widget _groupsList() => _loadingOr(
        () => ListView.builder(
          itemCount: _groups.length,
          itemBuilder: (_, i) {
            final g = _groups[i];
            final name = (g['name'] as String?) ?? 'Gruppe';
            return ListTile(
              leading: const Icon(LucideIcons.users, color: MnColors.teal),
              title: RichText(text: TextSpan(children: _highlight(name, _q))),
              subtitle: Text(
                (g['description'] as String?) ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MnTypography.caption(),
              ),
              onTap: () => GoRouter.of(context).push('/modules/gruppen/${g['id']}'),
            );
          },
        ),
        _groups,
        'Gruppen folgen.',
      );

  // ── EVENTS ────────────────────────────────────────────────────────────
  Widget _eventsList() => _loadingOr(
        () => ListView.builder(
          itemCount: _events.length,
          itemBuilder: (_, i) {
            final e = _events[i];
            final title = (e['title'] as String?) ?? 'Veranstaltung';
            final startsAt = (e['starts_at'] as String?) ?? '';
            final date = startsAt.length >= 10 ? startsAt.substring(0, 10) : startsAt;
            return ListTile(
              leading: const Icon(LucideIcons.calendar, color: MnColors.amber),
              title: RichText(text: TextSpan(children: _highlight(title, _q))),
              subtitle: Text(
                date,
                style: MnTypography.mono(size: 12, color: MnColors.mute),
              ),
              onTap: () => GoRouter.of(context).push('/modules/events/${e['id']}'),
            );
          },
        ),
        _events,
        'Events folgen.',
      );

  // ── WIKI ──────────────────────────────────────────────────────────────
  Widget _wikiList() => _loadingOr(
        () => ListView.builder(
          itemCount: _wiki.length,
          itemBuilder: (_, i) {
            final w = _wiki[i];
            final title = (w['title'] as String?) ?? 'Artikel';
            final content = (w['content'] as String?) ?? '';
            final preview = content.length > 100
                ? '${content.substring(0, 100)}...'
                : content;
            return ListTile(
              leading: const Icon(LucideIcons.bookOpen, color: MnColors.trust),
              title: RichText(text: TextSpan(children: _highlight(title, _q))),
              subtitle: Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MnTypography.caption(),
              ),
              onTap: () => GoRouter.of(context).push('/modules/wissen/${w['id']}'),
            );
          },
        ),
        _wiki,
        'Wiki folgt.',
      );
}

// Silence unused-import lint for NachbarschaftCard if removed.
// ignore: unused_element
typedef _Unused = NachbarschaftCard;
