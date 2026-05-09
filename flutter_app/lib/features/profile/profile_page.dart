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
      // Stats parallel laden, ohne UI zu blockieren
      unawaited(_loadStats(user.id));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary500.withValues(alpha: 0.2),
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(initial,
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700))
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
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.ink400),
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
            const SizedBox(height: 20),
            _StatsRow(stats: _stats),
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
    required this.scrollController,
  });

  final String initialName;
  final String initialBio;
  final String initialCity;
  final String? initialAvatarUrl;
  final ScrollController scrollController;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _bio = TextEditingController(text: widget.initialBio);
  late final _city = TextEditingController(text: widget.initialCity);
  String? _avatarUrl;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _city.dispose();
    super.dispose();
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
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
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
                            ? Text(initial,
                                style: const TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.w700))
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
