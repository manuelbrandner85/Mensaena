import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// Eigene Profil-Seite (/dashboard/profile). Pendant zur Web-/profile-Page.
/// Zeigt Avatar, Name, Email, Stats-Bar + Aktionen (Bearbeiten, Settings, Logout).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? _profile;
  _ProfileStats _stats = const _ProfileStats();
  List<_ActivityItem> _activity = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final row = await db
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _profile = row;
        _loading = false;
      });
      // Stats + Activity parallel laden, ohne UI zu blockieren
      unawaited(_loadStats(user.id));
      unawaited(_loadActivity(user.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Lädt einen kompakten Activity-Feed (Posts, Group-Joins, Challenges)
  /// und merged ihn nach Zeit absteigend. Pendant zum Web-`ProfileActivityFeed`.
  Future<void> _loadActivity(String userId) async {
    final db = ref.read(supabaseProvider);
    Future<List<dynamic>> safeQuery(Future<List<dynamic>> Function() q) async {
      try {
        return await q();
      } catch (_) {
        return const [];
      }
    }

    final results = await Future.wait([
      safeQuery(
        () async => db
            .from('posts')
            .select('id, title, created_at, type')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(10),
      ),
      safeQuery(
        () async => db
            .from('group_members')
            .select('joined_at, group_id, groups(name)')
            .eq('user_id', userId)
            .order('joined_at', ascending: false)
            .limit(10),
      ),
      safeQuery(
        () async => db
            .from('challenge_participants')
            .select('joined_at, challenge_id, challenges(name, title)')
            .eq('user_id', userId)
            .order('joined_at', ascending: false)
            .limit(10),
      ),
    ]);

    final items = <_ActivityItem>[];
    for (final p in results[0]) {
      final m = p as Map<String, dynamic>;
      final ts = DateTime.tryParse(m['created_at'] as String? ?? '');
      if (ts == null) continue;
      items.add(_ActivityItem(
        kind: _ActivityKind.post,
        title: (m['title'] as String?) ?? 'Beitrag',
        when: ts,
      ));
    }
    for (final g in results[1]) {
      final m = g as Map<String, dynamic>;
      final ts = DateTime.tryParse(m['joined_at'] as String? ?? '');
      if (ts == null) continue;
      final group = m['groups'] as Map<String, dynamic>?;
      items.add(_ActivityItem(
        kind: _ActivityKind.group,
        title: (group?['name'] as String?) ?? 'Gruppe',
        when: ts,
      ));
    }
    for (final c in results[2]) {
      final m = c as Map<String, dynamic>;
      final ts = DateTime.tryParse(m['joined_at'] as String? ?? '');
      if (ts == null) continue;
      final challenge = m['challenges'] as Map<String, dynamic>?;
      final name = (challenge?['title'] as String?) ??
          (challenge?['name'] as String?) ??
          'Challenge';
      items.add(_ActivityItem(
        kind: _ActivityKind.challenge,
        title: name,
        when: ts,
      ));
    }
    items.sort((a, b) => b.when.compareTo(a.when));
    if (!mounted) return;
    setState(() => _activity = items.take(10).toList(growable: false));
  }

  Future<void> _loadStats(String userId) async {
    final db = ref.read(supabaseProvider);
    Future<int> countQuery(String table, String filter, String value) async {
      try {
        final rows = await db.from(table).select('id').eq(filter, value);
        return rows.length;
      } catch (_) {
        return 0;
      }
    }

    final results = await Future.wait([
      countQuery('posts', 'user_id', userId),
      countQuery('group_members', 'user_id', userId),
      countQuery('challenge_participants', 'user_id', userId),
      countQuery('user_badges', 'user_id', userId),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = _ProfileStats(
        postsCount: results[0],
        groupsCount: results[1],
        challengesCount: results[2],
        badgesCount: results[3],
      );
    });
  }

  Future<void> _openEdit() async {
    final p = _profile;
    if (p == null) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scroll) => _EditSheet(
          initialName: p['name'] as String? ?? '',
          initialBio: p['bio'] as String? ?? '',
          initialCity: p['city'] as String? ?? '',
          initialAvatarUrl: p['avatar_url'] as String?,
          initialCoverUrl: p['cover_url'] as String?,
          initialPhone: p['phone'] as String? ?? '',
          initialHomepage: p['homepage'] as String? ?? '',
          initialShowPhone: (p['show_phone'] as bool?) ?? false,
          scrollController: scroll,
        ),
      ),
    );
    if (updated != null) {
      setState(() => _profile = {...?_profile, ...updated});
    }
  }

  Future<void> _logout() async {
    await ref.read(supabaseProvider).auth.signOut();
    if (!mounted) return;
    context.go(Routes.auth);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _profile;
    final user = ref.read(supabaseProvider).auth.currentUser;
    final name = p?['name'] as String? ?? user?.email ?? 'Profil';
    final email = user?.email ?? '';
    final avatarUrl = p?['avatar_url'] as String?;
    final bio = p?['bio'] as String?;
    final city = p?['city'] as String?;
    final trustScore = (p?['trust_score'] as num?)?.toDouble() ?? 0;
    final trustCount = (p?['trust_score_count'] as num?)?.toInt() ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final coverUrl = p?['cover_url'] as String?;
    final offerTags = p?['offer_tags'] is List
        ? List<String>.from((p!['offer_tags'] as List).whereType<String>())
        : <String>[];
    final seekTags = p?['seek_tags'] is List
        ? List<String>.from((p!['seek_tags'] as List).whereType<String>())
        : <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mein Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(Routes.dashboardSettings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            // Cover-Banner (gradient fallback, sonst Bild) — full width via
            // negative-margin-Trick, da wir die ListView-Padding behalten
            Container(
              margin: const EdgeInsets.symmetric(horizontal: -16),
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary500, AppColors.primary700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: coverUrl != null
                    ? DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  Material(
                    color: AppColors.primary500,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openEdit,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.edit, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                email,
                style: const TextStyle(color: AppColors.ink400, fontSize: 13),
              ),
            ),
            if (city != null && city.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.ink400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: const TextStyle(color: AppColors.ink400, fontSize: 13),
                    ),
                  ],
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
            if (offerTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              _TagsBlock(
                title: '🎁 Ich biete',
                tags: offerTags,
                accent: AppColors.primary500,
              ),
            ],
            if (seekTags.isNotEmpty) ...[
              const SizedBox(height: 12),
              _TagsBlock(
                title: '🔍 Ich suche',
                tags: seekTags,
                accent: const Color(0xFF3B82F6),
              ),
            ],
            const SizedBox(height: 20),
            _StatsRow(stats: _stats),
            if (_activity.isNotEmpty) ...[
              const SizedBox(height: 20),
              _ActivityFeed(items: _activity),
            ],
            const SizedBox(height: 24),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: 'Profil bearbeiten',
              onTap: _openEdit,
            ),
            _ActionTile(
              icon: Icons.workspace_premium_outlined,
              label: 'Badges',
              onTap: () => context.go(Routes.dashboardBadges),
            ),
            _ActionTile(
              icon: Icons.share_outlined,
              label: 'Einladen',
              onTap: () => context.go(Routes.dashboardInvite),
            ),
            _ActionTile(
              icon: Icons.calendar_month_outlined,
              label: 'Kalender',
              onTap: () => context.go(Routes.dashboardCalendar),
            ),
            _ActionTile(
              icon: Icons.notifications_outlined,
              label: 'Benachrichtigungen',
              onTap: () => context.go(Routes.dashboardNotifications),
            ),
            _ActionTile(
              icon: Icons.settings_outlined,
              label: 'Einstellungen',
              onTap: () => context.go(Routes.dashboardSettings),
            ),
            const Divider(height: 32),
            _ActionTile(
              icon: Icons.logout,
              label: 'Abmelden',
              destructive: true,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

void unawaited(Future<void> future) {}

class _ProfileStats {
  const _ProfileStats({
    this.postsCount = 0,
    this.groupsCount = 0,
    this.challengesCount = 0,
    this.badgesCount = 0,
  });
  final int postsCount;
  final int groupsCount;
  final int challengesCount;
  final int badgesCount;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final _ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = <_StatCardData>[
      _StatCardData(
        icon: Icons.article_outlined,
        label: 'Posts',
        value: '${stats.postsCount}',
      ),
      _StatCardData(
        icon: Icons.group_outlined,
        label: 'Gruppen',
        value: '${stats.groupsCount}',
      ),
      _StatCardData(
        icon: Icons.emoji_events_outlined,
        label: 'Challenges',
        value: '${stats.challengesCount}',
      ),
      _StatCardData(
        icon: Icons.workspace_premium_outlined,
        label: 'Badges',
        value: '${stats.badgesCount}',
      ),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: cards.map((c) => _StatCard(data: c)).toList(),
    );
  }
}

class _StatCardData {
  const _StatCardData({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, size: 18, color: AppColors.primary500),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.ink800,
            ),
          ),
          Text(
            data.label,
            style: const TextStyle(
              color: AppColors.ink400,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFB91C1C) : AppColors.ink800;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.ink400),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit-Sheet ───────────────────────────────────────────────────────────────

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({
    required this.initialName,
    required this.initialBio,
    required this.initialCity,
    required this.initialAvatarUrl,
    required this.initialCoverUrl,
    required this.initialPhone,
    required this.initialHomepage,
    required this.initialShowPhone,
    required this.scrollController,
  });

  final String initialName;
  final String initialBio;
  final String initialCity;
  final String? initialAvatarUrl;
  final String? initialCoverUrl;
  final String initialPhone;
  final String initialHomepage;
  final bool initialShowPhone;
  final ScrollController scrollController;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _bio = TextEditingController(text: widget.initialBio);
  late final _city = TextEditingController(text: widget.initialCity);
  late final _phone = TextEditingController(text: widget.initialPhone);
  late final _homepage = TextEditingController(text: widget.initialHomepage);
  String? _avatarUrl;
  String? _coverUrl;
  late bool _showPhone = widget.initialShowPhone;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.initialAvatarUrl;
    _coverUrl = widget.initialCoverUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _city.dispose();
    _phone.dispose();
    _homepage.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    if (_uploadingCover) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _uploadingCover = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      final ext = picked.name.split('.').last.toLowerCase();
      final path =
          '${user.id}/cover-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await picked.readAsBytes();
      await db.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = db.storage.from('avatars').getPublicUrl(path);
      if (!mounted) return;
      setState(() => _coverUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cover-Upload fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      final ext = picked.name.split('.').last.toLowerCase();
      final path = '${user.id}/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await picked.readAsBytes();
      await db.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = db.storage.from('avatars').getPublicUrl(path);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      final updates = <String, dynamic>{
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'city': _city.text.trim(),
        'phone': _phone.text.trim(),
        'homepage': _homepage.text.trim(),
        'show_phone': _showPhone,
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
        if (_coverUrl != null) 'cover_url': _coverUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await db.from('profiles').update(updates).eq('id', user.id);
      if (!mounted) return;
      Navigator.of(context).pop(updates);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.isNotEmpty ? _name.text[0].toUpperCase() : '?';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Profil bearbeiten',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
                        backgroundImage:
                            _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _avatarUrl == null
                            ? Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      Material(
                        color: AppColors.primary500,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploadingAvatar ? null : _pickAvatar,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _uploadingAvatar
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _Label('Name'),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _deco('Wie heißt du?'),
                ),
                const SizedBox(height: 12),
                const _Label('Bio'),
                TextField(
                  controller: _bio,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _deco('Erzähl etwas über dich'),
                ),
                const SizedBox(height: 12),
                const _Label('Stadt'),
                TextField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: _deco('z. B. Wien'),
                ),
                const SizedBox(height: 12),
                const _Label('Telefon'),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: _deco('+43 660 …'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Telefonnummer im Profil zeigen',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Andere Nachbarn sehen deine Nummer in deinem öffentlichen Profil.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _showPhone,
                  onChanged: (v) => setState(() => _showPhone = v),
                ),
                const SizedBox(height: 4),
                const _Label('Webseite'),
                TextField(
                  controller: _homepage,
                  keyboardType: TextInputType.url,
                  decoration: _deco('https://…'),
                ),
                const SizedBox(height: 16),
                const _Label('Cover-Bild'),
                _CoverPickerCard(
                  coverUrl: _coverUrl,
                  uploading: _uploadingCover,
                  onTap: _uploadingCover ? null : _pickCover,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Speichere…' : 'Speichern'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

class _CoverPickerCard extends StatelessWidget {
  const _CoverPickerCard({
    required this.coverUrl,
    required this.uploading,
    required this.onTap,
  });

  final String? coverUrl;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      color: AppColors.primary500.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary500, AppColors.primary700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            image: coverUrl != null
                ? DecorationImage(
                    image: NetworkImage(coverUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: uploading
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        coverUrl == null ? 'Cover wählen' : 'Cover ändern',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.ink400,
        ),
      ),
    );
  }
}

class _TagsBlock extends StatelessWidget {
  const _TagsBlock({
    required this.title,
    required this.tags,
    required this.accent,
  });
  final String title;
  final List<String> tags;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#$t',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

enum _ActivityKind { post, group, challenge }

class _ActivityItem {
  const _ActivityItem({
    required this.kind,
    required this.title,
    required this.when,
  });
  final _ActivityKind kind;
  final String title;
  final DateTime when;
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.items});
  final List<_ActivityItem> items;

  String _relative(DateTime t) {
    final delta = DateTime.now().difference(t);
    if (delta.inDays >= 30) {
      return '${(delta.inDays / 30).floor()} Monaten';
    }
    if (delta.inDays >= 1) return 'vor ${delta.inDays} Tagen';
    if (delta.inHours >= 1) return 'vor ${delta.inHours} Std.';
    if (delta.inMinutes >= 1) return 'vor ${delta.inMinutes} Min.';
    return 'gerade eben';
  }

  ({IconData icon, Color color, String label}) _meta(_ActivityKind k) {
    switch (k) {
      case _ActivityKind.post:
        return (
          icon: Icons.article_outlined,
          color: AppColors.primary500,
          label: 'Beitrag',
        );
      case _ActivityKind.group:
        return (
          icon: Icons.group_outlined,
          color: const Color(0xFF8B5CF6),
          label: 'Gruppe beigetreten',
        );
      case _ActivityKind.challenge:
        return (
          icon: Icons.emoji_events_outlined,
          color: const Color(0xFFD97706),
          label: 'Challenge gestartet',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stone200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, size: 16, color: AppColors.primary500),
              SizedBox(width: 8),
              Text(
                'Letzte Aktivitäten',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((it) {
            final m = _meta(it.kind);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: m.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(m.icon, size: 14, color: m.color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: m.color,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          it.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relative(it.when),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.ink400,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
