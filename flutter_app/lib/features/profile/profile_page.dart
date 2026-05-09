import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// Eigene Profil-Seite (/dashboard/profile). Pendant zur Web-/profile-Page.
/// Zeigt Avatar, Name, Email + Aktionen (Settings, Logout).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? _profile;
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
              child: CircleAvatar(
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
            if (city != null) ...[
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
                child: Text(
                  bio,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: 'Profil bearbeiten',
              onTap: () => context.go(Routes.dashboardSettings),
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
