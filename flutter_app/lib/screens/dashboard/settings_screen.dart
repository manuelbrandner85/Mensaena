import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/profile.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Settings-Screen mit 5 Tabs (Account/Privacy/Notifications/Region/Danger).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  Future<Profile?>? _future;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _future = ProfilesRepository.getMine();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    await ProfilesRepository.update(uid, patch);
    setState(() => _future = ProfilesRepository.getMine());
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Einstellungen',
      currentRoute: '/dashboard/settings',
      body: Column(
        children: [
          Container(
            color: AppColors.deep,
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              indicatorColor: AppColors.amber,
              labelColor: AppColors.amber,
              unselectedLabelColor: AppColors.inkSoft,
              labelStyle: AppTypography.label(size: 11),
              tabs: const [
                Tab(text: 'Account'),
                Tab(text: 'Privatsphäre'),
                Tab(text: 'Benachrichtigungen'),
                Tab(text: 'Standort'),
                Tab(text: 'Konto'),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Profile?>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.amber),
                  );
                }
                final p = snap.data;
                if (p == null) {
                  return Center(
                    child: Text('Profil nicht gefunden.',
                        style: AppTypography.caption()),
                  );
                }
                return TabBarView(
                  controller: _tab,
                  children: [
                    _AccountTab(profile: p),
                    _PrivacyTab(profile: p, onPatch: _patch),
                    _NotifTab(profile: p, onPatch: _patch),
                    _RegionTab(profile: p, onPatch: _patch),
                    _DangerTab(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTab extends StatelessWidget {
  const _AccountTab({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('E-Mail', style: AppTypography.label(size: 10)),
        const SizedBox(height: 4),
        Text(profile.email ?? '–',
            style: AppTypography.body(size: 14, color: AppColors.ink)),
        const SizedBox(height: 18),
        Text('Name', style: AppTypography.label(size: 10)),
        const SizedBox(height: 4),
        Text(profile.name ?? '–',
            style: AppTypography.body(size: 14, color: AppColors.ink)),
        const SizedBox(height: 24),
        Text(
          'Email- und Profil-Daten kannst du im vollen Web-Dashboard '
          '(www.mensaena.de) bearbeiten — In-App folgt in einer spaeteren Phase.',
          style: AppTypography.caption(),
        ),
      ],
    );
  }
}

class _PrivacyTab extends StatelessWidget {
  const _PrivacyTab({required this.profile, required this.onPatch});
  final Profile profile;
  final Future<void> Function(Map<String, dynamic>) onPatch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _BoolTile(
          label: 'Online-Status zeigen',
          value: profile.showOnlineStatus,
          onChanged: (v) => onPatch({'show_online_status': v}),
        ),
        _BoolTile(
          label: 'Standort zeigen',
          value: profile.showLocation,
          onChanged: (v) => onPatch({'show_location': v}),
        ),
        _BoolTile(
          label: 'Trust-Score zeigen',
          value: profile.showTrustScore,
          onChanged: (v) => onPatch({'show_trust_score': v}),
        ),
        _BoolTile(
          label: 'Aktivität zeigen',
          value: profile.showActivity,
          onChanged: (v) => onPatch({'show_activity': v}),
        ),
        _BoolTile(
          label: 'Telefon zeigen',
          value: profile.showPhone,
          onChanged: (v) => onPatch({'show_phone': v}),
        ),
        const SizedBox(height: 16),
        Text('Profil-Sichtbarkeit', style: AppTypography.label(size: 10)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: ['public', 'neighbors', 'private'].map((v) {
            final active = profile.profileVisibility == v;
            return GestureDetector(
              onTap: () => onPatch({'profile_visibility': v}),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.amber.withValues(alpha: 0.2)
                      : AppColors.surface.withValues(alpha: 0.5),
                  border: Border.all(
                    color: active ? AppColors.amber : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _label(v),
                  style: AppTypography.label(
                    size: 10,
                    color: active ? AppColors.amber : AppColors.inkSoft,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static String _label(String v) {
    switch (v) {
      case 'public':
        return 'Öffentlich';
      case 'neighbors':
        return 'Nur Nachbarn';
      case 'private':
        return 'Privat';
      default:
        return v;
    }
  }
}

class _NotifTab extends StatelessWidget {
  const _NotifTab({required this.profile, required this.onPatch});
  final Profile profile;
  final Future<void> Function(Map<String, dynamic>) onPatch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _BoolTile(
          label: 'Nachrichten',
          value: profile.notifyNewMessages,
          onChanged: (v) => onPatch({'notify_new_messages': v}),
        ),
        _BoolTile(
          label: 'Interaktionen',
          value: profile.notifyNewInteractions,
          onChanged: (v) => onPatch({'notify_new_interactions': v}),
        ),
        _BoolTile(
          label: 'Beiträge in der Nähe',
          value: profile.notifyNearbyPosts,
          onChanged: (v) => onPatch({'notify_nearby_posts': v}),
        ),
        _BoolTile(
          label: 'Trust-Bewertungen',
          value: profile.notifyTrustRatings,
          onChanged: (v) => onPatch({'notify_trust_ratings': v}),
        ),
        _BoolTile(
          label: 'System',
          value: profile.notifySystem,
          onChanged: (v) => onPatch({'notify_system': v}),
        ),
        _BoolTile(
          label: 'Push-Notifications',
          value: profile.notifyPush,
          onChanged: (v) => onPatch({'notify_push': v}),
        ),
        _BoolTile(
          label: 'E-Mail-Benachrichtigungen',
          value: profile.notifyEmail,
          onChanged: (v) => onPatch({'notify_email': v}),
        ),
      ],
    );
  }
}

class _RegionTab extends StatelessWidget {
  const _RegionTab({required this.profile, required this.onPatch});
  final Profile profile;
  final Future<void> Function(Map<String, dynamic>) onPatch;

  @override
  Widget build(BuildContext context) {
    final radius = (profile.radiusKm ?? 10).toDouble();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Standort', style: AppTypography.label(size: 10)),
        const SizedBox(height: 4),
        Text(
          profile.location ?? 'Nicht gesetzt',
          style: AppTypography.body(size: 14, color: AppColors.ink),
        ),
        const SizedBox(height: 18),
        Text('Radius: ${radius.toInt()} km',
            style: AppTypography.label(size: 10)),
        Slider(
          activeColor: AppColors.amber,
          inactiveColor: AppColors.elevated,
          value: radius,
          min: 1,
          max: 150,
          divisions: 149,
          onChanged: (v) {},
          onChangeEnd: (v) => onPatch({'radius_km': v.toInt()}),
        ),
      ],
    );
  }
}

class _DangerTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Konto', style: AppTypography.label(size: 10)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () async {
            await sb.auth.signOut();
            if (context.mounted) context.go('/');
          },
          icon: const Icon(LucideIcons.logOut, size: 16),
          label: const Text('Abmelden'),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.herzrot.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.herzrot.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Konto löschen',
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.herzrotWarm,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Per DSGVO-Anfrage an info@mensaena.de oder im vollen Web-'
                'Dashboard. In-App-Loeschung folgt in einer spaeteren Phase.',
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.inkSoft,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BoolTile extends StatelessWidget {
  const _BoolTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.amber,
      value: value,
      onChanged: onChanged,
      title: Text(
        label,
        style: AppTypography.body(size: 14, color: AppColors.ink),
      ),
    );
  }
}
