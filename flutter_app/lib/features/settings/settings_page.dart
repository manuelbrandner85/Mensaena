import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// /dashboard/settings — sektionierte Einstellungen.
/// Pendant zu src/app/dashboard/settings (Web).
/// Sektionen: Profil-Info · Privatsphäre · Benachrichtigungen · Account.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Map<String, dynamic> _profile = const {};
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
        _profile = row ?? const {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _patch(Map<String, dynamic> updates) async {
    final db = ref.read(supabaseProvider);
    final user = db.auth.currentUser;
    if (user == null) return;
    HapticFeedback.lightImpact();
    try {
      await db.from('profiles').update(<String, dynamic>{
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      if (!mounted) return;
      setState(() => _profile = {..._profile, ...updates});
    } catch (e) {
      // Silently swallow „column does not exist" – Web-Hook macht das auch
      if (!mounted) return;
      if (!'$e'.contains('does not exist')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(supabaseProvider).auth.signOut();
    if (!mounted) return;
    context.go(Routes.auth);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account löschen?'),
        content: const Text(
          'Dein Account wird unwiderruflich gelöscht. Posts, Nachrichten und '
          'alle Daten werden entfernt. Diese Aktion kann nicht rückgängig '
          'gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      // Versucht direkten DELETE – falls RLS das nicht erlaubt, wird ein
      // Backend-Helper-Endpoint via /api/account/delete benötigt (folgt).
      await db.from('profiles').delete().eq('id', user.id);
      await db.auth.signOut();
      if (!mounted) return;
      context.go(Routes.auth);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final email = ref.read(supabaseProvider).auth.currentUser?.email ?? '';
    final visibility = _profile['profile_visibility'] as String? ?? 'public';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profil ────────────────────────────────────────────────
          const _SectionHeader(label: 'Profil'),
          _LinkRow(
            icon: Icons.person_outlined,
            label: 'Profil bearbeiten',
            sub: 'Name, Bio, Stadt, Avatar',
            onTap: () => context.go(Routes.dashboardProfile),
          ),

          const SizedBox(height: 20),
          // ── Privatsphäre ──────────────────────────────────────────
          const _SectionHeader(label: 'Privatsphäre'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profil-Sichtbarkeit',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Wer kann dein Profil und deine Posts sehen?',
                        style: TextStyle(color: AppColors.ink400, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final opt in const [
                            ('public', 'Öffentlich', Icons.public),
                            ('friends', 'Freunde', Icons.people_outline),
                            ('private', 'Privat', Icons.lock_outline),
                          ])
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    _patch({'profile_visibility': opt.$1}),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: visibility == opt.$1
                                        ? AppColors.primary500.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: visibility == opt.$1
                                          ? AppColors.primary500
                                          : Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        opt.$3,
                                        size: 18,
                                        color: visibility == opt.$1
                                            ? AppColors.primary500
                                            : AppColors.ink400,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        opt.$2,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: visibility == opt.$1
                                              ? AppColors.primary500
                                              : AppColors.ink400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          // ── Benachrichtigungen ────────────────────────────────────
          const _SectionHeader(label: 'Benachrichtigungen'),
          _ToggleGroup(
            items: [
              _ToggleItem(
                label: 'Neue Nachrichten',
                description: 'DM-Posteingang',
                column: 'notify_new_messages',
                value: _profile['notify_new_messages'] as bool? ?? true,
              ),
              _ToggleItem(
                label: 'Interaktionen',
                description: 'Hilfsanfragen + Antworten',
                column: 'notify_new_interactions',
                value: _profile['notify_new_interactions'] as bool? ?? true,
              ),
              _ToggleItem(
                label: 'Posts in der Nähe',
                description: 'Neue Posts in deiner Stadt',
                column: 'notify_nearby_posts',
                value: _profile['notify_nearby_posts'] as bool? ?? true,
              ),
              _ToggleItem(
                label: 'Bewertungen',
                description: 'Wenn du Trust-Score erhältst',
                column: 'notify_trust_ratings',
                value: _profile['notify_trust_ratings'] as bool? ?? true,
              ),
              _ToggleItem(
                label: 'System',
                description: 'Wichtige Updates und Events',
                column: 'notify_system',
                value: _profile['notify_system'] as bool? ?? true,
              ),
              _ToggleItem(
                label: 'E-Mail',
                description: 'Zusätzlich per Email benachrichtigen',
                column: 'notify_email',
                value: _profile['notify_email'] as bool? ?? false,
              ),
              _ToggleItem(
                label: 'Push',
                description: 'Push-Benachrichtigungen aufs Handy',
                column: 'notify_push',
                value: _profile['notify_push'] as bool? ?? true,
              ),
              _ToggleItem(
                label: 'Sound',
                description: 'Klang bei neuen Benachrichtigungen',
                column: 'notify_sound',
                value: _profile['notify_sound'] as bool? ?? true,
              ),
            ],
            onChange: (col, v) => _patch({col: v}),
          ),

          const SizedBox(height: 20),
          // ── Account ───────────────────────────────────────────────
          const _SectionHeader(label: 'Account'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.email_outlined,
                          size: 18, color: AppColors.ink400),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('E-Mail',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                              email,
                              style: const TextStyle(
                                color: AppColors.ink400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _LinkRow(
                  icon: Icons.lock_outline,
                  label: 'Passwort ändern',
                  onTap: _changePassword,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          // ── Gefährliche Aktionen ─────────────────────────────────
          const _SectionHeader(label: 'Gefährliche Zone', accent: Color(0xFFB91C1C)),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _LinkRow(
                  icon: Icons.logout,
                  label: 'Abmelden',
                  destructive: true,
                  onTap: _logout,
                ),
                const Divider(height: 1),
                _LinkRow(
                  icon: Icons.delete_forever_outlined,
                  label: 'Account löschen',
                  destructive: true,
                  onTap: _confirmDelete,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final db = ref.read(supabaseProvider);
    final email = db.auth.currentUser?.email;
    if (email == null) return;
    try {
      await db.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://www.mensaena.de/auth?mode=reset',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Passwort-Reset-Link wurde an deine E-Mail geschickt.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }
}

// ─── Sub-Widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.accent});
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: accent ?? AppColors.ink400,
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sub,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? sub;
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
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub!,
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 12,
                        ),
                      ),
                  ],
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

class _ToggleItem {
  const _ToggleItem({
    required this.label,
    required this.description,
    required this.column,
    required this.value,
  });
  final String label;
  final String description;
  final String column;
  final bool value;
}

class _ToggleGroup extends StatelessWidget {
  const _ToggleGroup({required this.items, required this.onChange});
  final List<_ToggleItem> items;
  final void Function(String column, bool value) onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: SwitchListTile.adaptive(
                value: items[i].value,
                onChanged: (v) => onChange(items[i].column, v),
                title: Text(
                  items[i].label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  items[i].description,
                  style: const TextStyle(
                    color: AppColors.ink400,
                    fontSize: 12,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
