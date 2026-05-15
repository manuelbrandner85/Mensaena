import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../posts/models.dart';
import '../posts/posts_repository.dart';

/// Globale Suche: Volltext über Posts (via `search_posts` RPC, German tsvector)
/// + parallele Profile-Suche (ilike auf name/email). Beide Resultate werden
/// in zwei Sektionen unter dem Search-Field gerendert.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _lastQuery = '';
  bool _loading = false;
  List<Post> _posts = const [];
  List<Map<String, dynamic>> _profiles = const [];

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value.trim());
    });
  }

  Future<void> _runSearch(String q) async {
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.isEmpty) {
      setState(() {
        _posts = const [];
        _profiles = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(postsRepositoryProvider);
      final db = ref.read(supabaseProvider);
      final results = await Future.wait([
        repo.searchPostsRpc(query: q, limit: 15),
        _searchProfiles(db, q),
      ]);
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _posts = results[0] as List<Post>;
        _profiles = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suche fehlgeschlagen: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _searchProfiles(
    SupabaseClient db,
    String q,
  ) async {
    final safe = q.replaceAll(RegExp(r'[%_\\,()]'), ' ').trim();
    if (safe.isEmpty) return const [];
    final rows = await db
        .from('profiles')
        .select('id, name, avatar_url, city, bio')
        .or('name.ilike.%$safe%,bio.ilike.%$safe%,city.ilike.%$safe%')
        .limit(15);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    final empty = _posts.isEmpty && _profiles.isEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: _runSearch,
          decoration: InputDecoration(
            hintText: 'Suche nach Beiträgen, Personen, Orten …',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _onQueryChanged('');
                    },
                  ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lastQuery.isEmpty
              ? const _HintState()
              : empty
                  ? _EmptyState(query: _lastQuery)
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        if (_profiles.isNotEmpty) ...[
                          const _SectionHeader(
                            label: 'Personen',
                            icon: Icons.people_outline,
                          ),
                          ..._profiles.map(
                            (p) => _ProfileTile(profile: p),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_posts.isNotEmpty) ...[
                          const _SectionHeader(
                            label: 'Hilfe-Posts',
                            icon: Icons.article_outlined,
                          ),
                          ..._posts.map((p) => _PostTile(post: p)),
                        ],
                      ],
                    ),
    );
  }
}

class _HintState extends StatelessWidget {
  const _HintState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: AppColors.stone400),
            SizedBox(height: 12),
            Text(
              'Was suchst du?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Hilfe-Anfragen, Personen in deiner Nachbarschaft, '
              'oder Themen aus dem Wiki.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.ink400),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🕊️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Nichts zu "$query" gefunden',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Versuche andere Begriffe oder eine andere Schreibweise.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.ink400),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary500),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.ink700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final name = (profile['name'] as String?) ?? 'Unbekannt';
    final avatar = profile['avatar_url'] as String?;
    final city = profile['city'] as String?;
    final bio = profile['bio'] as String?;
    return ListTile(
      onTap: () =>
          context.go('${Routes.dashboardProfile}/${profile['id']}'),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.stone200,
        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
        child: avatar == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink400,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        city != null && city.isNotEmpty
            ? city
            : (bio ?? '').replaceAll('\n', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AppColors.ink400),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.ink400),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final cat = post.typeConfig;
    final distance = post.distanceKm;
    return ListTile(
      onTap: () => context.go('${Routes.dashboardPosts}/${post.id}'),
      leading: post.mediaUrls.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post.mediaUrls.first,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(width: 44, height: 44, color: AppColors.stone100),
                errorWidget: (_, __, ___) => Container(
                  width: 44,
                  height: 44,
                  color: AppColors.stone100,
                  alignment: Alignment.center,
                  child: Text(cat.emoji),
                ),
              ),
            )
          : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
            ),
      title: Text(
        post.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Row(
        children: [
          Text(
            cat.label,
            style: TextStyle(
              fontSize: 11,
              color: cat.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (distance != null) ...[
            const SizedBox(width: 6),
            Text(
              '· ${distance.toStringAsFixed(1)} km',
              style: const TextStyle(fontSize: 11, color: AppColors.ink400),
            ),
          ],
          if (post.locationText != null) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '· ${post.locationText}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.ink400,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.ink400),
    );
  }
}
