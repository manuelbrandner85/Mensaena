import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../messages/messages_repository.dart';
import '../posts/models.dart';
import '../posts/posts_page.dart' show PostListTile;

/// `/dashboard/profile/:userId` — fremdes Profil ansehen.
/// Zeigt Avatar, Name, Bio, Stadt, Trust-Score + DM-Button + letzte Posts.
class PublicProfilePage extends ConsumerStatefulWidget {
  const PublicProfilePage({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends ConsumerState<PublicProfilePage> {
  Map<String, dynamic>? _profile;
  List<Post> _posts = const [];
  bool _loading = true;
  String? _error;
  bool _busyDm = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = ref.read(supabaseProvider);
      final myId = db.auth.currentUser?.id;

      // Eigenes Profil → redirect
      if (myId != null && myId == widget.userId) {
        if (!mounted) return;
        context.go(Routes.dashboardProfile);
        return;
      }

      final row = await db
          .from('profiles')
          .select('*')
          .eq('id', widget.userId)
          .maybeSingle();
      if (row == null) {
        if (!mounted) return;
        setState(() {
          _error = 'not_found';
          _loading = false;
        });
        return;
      }

      // Privatsphäre-Check
      if (row['privacy_public'] == false) {
        if (!mounted) return;
        setState(() {
          _profile = row;
          _error = 'private';
          _loading = false;
        });
        return;
      }

      // Letzte Posts laden
      final postRows = await db
          .from('posts')
          .select('*, profiles(name, avatar_url, trust_score, trust_score_count)')
          .eq('user_id', widget.userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10);

      if (!mounted) return;
      setState(() {
        _profile = row;
        _posts = postRows.map(Post.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'error';
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _openDm() async {
    if (_busyDm) return;
    setState(() => _busyDm = true);
    try {
      final myId = ref.read(supabaseProvider).auth.currentUser?.id;
      if (myId == null) return;
      final convId = await ref.read(messagesRepositoryProvider).findOrCreateDirectConversation(
            userA: myId,
            userB: widget.userId,
          );
      if (!mounted) return;
      context.go('${Routes.dashboardChat}?conv=$convId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte Chat nicht öffnen: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyDm = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error == 'not_found') {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined, size: 48, color: AppColors.ink400),
                SizedBox(height: 12),
                Text(
                  'Profil nicht gefunden',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final p = _profile!;
    if (_error == 'private') {
      return Scaffold(
        appBar: AppBar(title: Text(p['name'] as String? ?? 'Profil')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: AppColors.ink400),
                SizedBox(height: 12),
                Text(
                  'Privates Profil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Diese Person hat ihr Profil privat geschaltet.',
                  style: TextStyle(color: AppColors.ink400),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final name = p['name'] as String? ?? 'Unbekannt';
    final avatarUrl = p['avatar_url'] as String?;
    final bio = p['bio'] as String?;
    final city = p['city'] as String?;
    final trustScore = (p['trust_score'] as num?)?.toDouble() ?? 0;
    final trustCount = (p['trust_score_count'] as num?)?.toInt() ?? 0;
    final created = p['created_at'] as String?;
    final memberSince = created != null
        ? DateFormat('MMM yyyy', 'de').format(DateTime.parse(created))
        : '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(initial, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700))
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            if (city != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.ink400),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: const TextStyle(color: AppColors.ink400, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            if (memberSince.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Mitglied seit $memberSince',
                  style: const TextStyle(color: AppColors.ink400, fontSize: 12),
                ),
              ),
            ],
            if (trustCount > 0) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary500.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⭐ ${trustScore.toStringAsFixed(1)} · $trustCount Bewertungen',
                    style: const TextStyle(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
            if (bio != null && bio.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(bio, style: const TextStyle(fontSize: 14, height: 1.6)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _busyDm ? null : _openDm,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Anschreiben'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary500),
              ),
            ),
            if (_posts.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'BEITRÄGE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: AppColors.ink400,
                  ),
                ),
              ),
              ..._posts.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PostListTile(post: p),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
