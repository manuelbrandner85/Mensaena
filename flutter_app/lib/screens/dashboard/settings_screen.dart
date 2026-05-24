import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope, UserAttributes;

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../config/theme/cinema_theme.dart';
import '../../models/profile.dart';
import '../../providers/cinema_provider.dart';
import '../../providers/locale_provider.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/sound_service.dart';
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
    _tab = TabController(length: 8, vsync: this);
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
      title: 'settings.title'.tr(),
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
              tabs: [
                Tab(text: 'settings.tabs.account'.tr()),
                Tab(text: 'settings.tabs.privacy'.tr()),
                Tab(text: 'settings.tabs.security'.tr()),
                Tab(text: 'settings.tabs.language'.tr()),
                Tab(text: 'settings.tabs.notifications'.tr()),
                Tab(text: 'settings.tabs.location'.tr()),
                Tab(text: 'settings.tabs.appearance'.tr()),
                Tab(text: 'settings.tabs.account2'.tr()),
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
                    const _SecurityTab(),
                    const _LanguageTab(),
                    _NotifTab(profile: p, onPatch: _patch),
                    _RegionTab(profile: p, onPatch: _patch),
                    const _AppearanceTab(),
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

class _DangerTab extends StatefulWidget {
  @override
  State<_DangerTab> createState() => _DangerTabState();
}

class _DangerTabState extends State<_DangerTab> {
  bool _exporting = false;
  bool _deleting = false;

  /// GDPR Article 20 — Right to Data Portability.
  /// Fetches user's data + writes JSON to system share-sheet.
  Future<void> _exportData() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    setState(() => _exporting = true);
    try {
      // Parallel fetch core tables
      final results = await Future.wait<List<dynamic>>([
        sb.from('profiles').select().eq('id', uid).limit(1),
        sb.from('posts').select().eq('user_id', uid),
        sb.from('post_comments').select().eq('user_id', uid),
        sb.from('messages').select().eq('sender_id', uid),
        sb.from('interactions').select().or('helper_id.eq.$uid,helped_id.eq.$uid'),
        sb.from('trust_ratings').select().or('rater_id.eq.$uid,rated_id.eq.$uid'),
        sb.from('notifications').select().eq('user_id', uid),
        sb.from('saved_posts').select().eq('user_id', uid),
        sb.from('badges').select().eq('user_id', uid).limit(0),
      ]);
      final exportData = <String, dynamic>{
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'user_id': uid,
        'note':
            'Mensaena GDPR Article 20 Export — Right to Data Portability',
        'profile': results[0].isNotEmpty ? results[0].first : null,
        'posts': results[1],
        'comments': results[2],
        'messages': results[3],
        'interactions': results[4],
        'trust_ratings': results[5],
        'notifications': results[6],
        'saved_posts': results[7],
        'badges': results[8],
      };
      final json = const JsonEncoder.withIndent('  ').convert(exportData);
      // Write to temp + share
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/mensaena-export-${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(json);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Mensaena Daten-Export',
        text: 'Dein Mensaena-Daten-Export (DSGVO Art. 20).',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Daten-Export erstellt (${(json.length / 1024).toStringAsFixed(1)} KB).',
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Export fehlgeschlagen: $e',
            style: AppTypography.body(
                size: 13, color: AppColors.herzrotWarm)),
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// GDPR Article 17 — Right to Erasure.
  /// 3-Stage confirmation flow: scary warning → typed confirmation →
  /// RPC delete_account → signOut.
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Konto unwiderruflich löschen?',
            style: AppTypography.body(
                size: 16, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text(
          'Dein Profil, alle Beiträge, Nachrichten, Bewertungen und '
          'gespeicherten Inhalte werden permanent gelöscht. Diese Aktion '
          'kann NICHT rückgängig gemacht werden.\n\n'
          'Hinweis: System-Logs (z.B. anonymisierte Audit-Einträge) '
          'können aus rechtlichen Gründen erhalten bleiben.',
          style: AppTypography.body(
              size: 13, color: AppColors.inkSoft, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: const Text('Weiter zur Bestätigung'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Stage 2: typed confirmation
    final typedConfirmation = await _showTypedConfirmation();
    if (typedConfirmation != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      // Try RPC first (admin_delete_user with self-permission).
      // Fallback: just sign out + flag profile is_banned (soft-delete).
      try {
        await sb.rpc<dynamic>('delete_my_account');
      } catch (_) {
        // Fallback if RPC missing: anonymize profile.
        final uid = SupabaseService.currentUser?.id;
        if (uid != null) {
          await sb.from('profiles').update({
            'name': 'Gelöschter Nutzer',
            'nickname': null,
            'bio': null,
            'avatar_url': null,
            'phone': null,
            'is_banned': true,
            'ban_reason': 'self_deleted_${DateTime.now().toUtc().toIso8601String()}',
          }).eq('id', uid);
        }
      }
      await sb.auth.signOut();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('Löschen fehlgeschlagen: $e',
            style: AppTypography.body(
                size: 13, color: AppColors.herzrotWarm)),
      ));
    }
  }

  Future<bool?> _showTypedConfirmation() {
    final ctrl = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final canDelete = ctrl.text.trim() == 'LÖSCHEN';
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Letzte Bestätigung',
                style: AppTypography.body(
                    size: 16,
                    color: AppColors.ink,
                    weight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tippe „LÖSCHEN" zur Bestätigung:',
                  style: AppTypography.body(
                      size: 13, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  onChanged: (_) => setLocalState(() {}),
                  style: AppTypography.body(
                      size: 14, color: AppColors.ink),
                  decoration: const InputDecoration(
                    hintText: 'LÖSCHEN',
                    filled: true,
                    fillColor: AppColors.elevated,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Abbrechen')),
              TextButton(
                onPressed: canDelete ? () => Navigator.pop(ctx, true) : null,
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.herzrot),
                child: const Text('Konto endgültig löschen'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('SITZUNG', style: AppTypography.label(size: 10)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            await sb.auth.signOut();
            if (context.mounted) context.go('/');
          },
          icon: const Icon(LucideIcons.logOut, size: 16),
          label: const Text('Abmelden'),
        ),
        const SizedBox(height: 24),
        Text('DATENSCHUTZ (DSGVO)', style: AppTypography.label(size: 10)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _exporting ? null : _exportData,
          icon: _exporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.amber))
              : const Icon(LucideIcons.download, size: 16),
          label: Text(_exporting
              ? 'Exportiere…'
              : 'Meine Daten herunterladen (Art. 20)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.amber,
            side: BorderSide(color: AppColors.amber.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(height: 24),
        Text('GEFAHRENZONE', style: AppTypography.label(size: 10)),
        const SizedBox(height: 10),
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
                'Permanente Löschung deines Accounts und aller Inhalte. '
                'DSGVO Artikel 17 — Recht auf Vergessenwerden.',
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.inkSoft,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _deleting ? null : _deleteAccount,
                  icon: _deleting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.voidColor))
                      : const Icon(LucideIcons.trash2, size: 16),
                  label: Text(_deleting
                      ? 'Lösche…'
                      : 'Konto unwiderruflich löschen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.herzrot,
                    foregroundColor: AppColors.voidColor,
                  ),
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

// ─────────────────────────────────────────────────────────────
// Erscheinungsbild — Tageszeit-adaptives Cinema-Theme
// ─────────────────────────────────────────────────────────────
class _AppearanceTab extends ConsumerWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(cinemaModeProvider);
    final phase = ref.watch(effectiveCinemaPhaseProvider);
    final spec =
        phase != null ? CinemaTheme.specFor(phase) : null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Live-Preview-Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.palette,
                      color: AppColors.bronze, size: 16),
                  const SizedBox(width: 6),
                  Text('AKTUELLE STIMMUNG',
                      style: AppTypography.label(
                          size: 9, color: AppColors.bronzeSoft)),
                ],
              ),
              const SizedBox(height: 8),
              if (spec == null)
                Text('Aus — pures Cinema-Dark.',
                    style: AppTypography.body(
                        size: 14, color: AppColors.ink))
              else ...[
                Row(
                  children: [
                    Text(spec.emoji,
                        style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(spec.label,
                              style: AppTypography.display(
                                  size: 20, color: AppColors.ink)),
                          Text('Cinema-Theme aktiv',
                              style: AppTypography.body(
                                  size: 12, color: AppColors.mute)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Mini-Preview der Phase-Farben
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: spec.bgStops,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.line),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('CINEMA-MODUS',
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 8),
        for (final m in CinemaMode.values)
          _ModeTile(
            mode: m,
            active: mode == m,
            onTap: () =>
                ref.read(cinemaModeProvider.notifier).set(m),
          ),
        const SizedBox(height: 16),
        Text('EFFEKT-STÄRKE',
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 8),
        _IntensityTiles(),
        const SizedBox(height: 16),
        Text('SOUND',
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 4),
        const _SoundToggle(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.go('/onboarding'),
          icon: const Icon(LucideIcons.play, size: 14),
          label: const Text('Onboarding-Tour erneut ansehen'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(
                color: AppColors.bronze.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.info,
                      size: 14, color: AppColors.mute),
                  const SizedBox(width: 6),
                  Text('Was ist das?',
                      style: AppTypography.label(
                          size: 10, color: AppColors.mute)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Die App ändert ihre Atmosphäre subtil je nach Tageszeit — Nacht ist tiefes Indigo, Sunset wird warm bronze-orange, Tag ist klar. 6 Cinema-Effekte (Gradient, Tint, Vignette, Film-Grain, Light-Leaks, Smooth-Transitions) sorgen für ein hyperrealistisches Film-Gefühl. Brand-Farben (Bronze, Amber) bleiben gleich.',
                style: AppTypography.body(
                    size: 12, color: AppColors.inkSoft, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SoundToggle extends ConsumerStatefulWidget {
  const _SoundToggle();

  @override
  ConsumerState<_SoundToggle> createState() => _SoundToggleState();
}

class _SoundToggleState extends ConsumerState<_SoundToggle> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    SoundService.isEnabled().then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = _enabled ?? true;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: v,
      onChanged: (next) async {
        await SoundService.setEnabled(next);
        if (mounted) setState(() => _enabled = next);
        if (next) SoundService.click();
      },
      activeColor: AppColors.bronze,
      title: Text('UI-Sounds',
          style: AppTypography.body(size: 14, color: AppColors.ink)),
      subtitle: Text(
        'Dezenter System-Klick bei Taps und Toggles.',
        style: AppTypography.body(size: 12, color: AppColors.mute),
      ),
    );
  }
}

class _IntensityTiles extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(cinemaIntensityProvider);
    return Row(
      children: [
        for (final i in CinemaIntensity.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () =>
                    ref.read(cinemaIntensityProvider.notifier).set(i),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: current == i
                        ? AppColors.amber.withValues(alpha: 0.18)
                        : AppColors.elevated,
                    border: Border.all(
                      color: current == i
                          ? AppColors.amber
                          : AppColors.line,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    i.label.split(' ').first,
                    style: AppTypography.body(
                      size: 11,
                      color: current == i
                          ? AppColors.amber
                          : AppColors.inkSoft,
                      weight: current == i
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.active,
    required this.onTap,
  });
  final CinemaMode mode;
  final bool active;
  final VoidCallback onTap;

  IconData get _icon {
    switch (mode) {
      case CinemaMode.auto:       return LucideIcons.clock;
      case CinemaMode.off:        return LucideIcons.power;
      case CinemaMode.forceNight: return LucideIcons.moon;
      case CinemaMode.forceDay:   return LucideIcons.sun;
      case CinemaMode.forceDusk:  return LucideIcons.sunset;
    }
  }

  String get _description {
    switch (mode) {
      case CinemaMode.auto:
        return 'Wechselt automatisch — 6 Phasen über den Tag verteilt.';
      case CinemaMode.off:
        return 'Keine Cinema-Effekte, pures Dark-Theme.';
      case CinemaMode.forceNight:
        return 'Tiefes Indigo, ruhig, kontrastreich.';
      case CinemaMode.forceDay:
        return 'Heller, klarer Tag-Modus.';
      case CinemaMode.forceDusk:
        return 'Hyperreal Sunset — warmes Amber, Light-Leaks.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? AppColors.bronze.withValues(alpha: 0.16)
              : AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(
            color: active ? AppColors.bronze : AppColors.line,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.bronze.withValues(alpha: 0.22)
                    : AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_icon,
                  size: 16,
                  color: active ? AppColors.bronze : AppColors.mute),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mode.label,
                      style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(_description,
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft)),
                ],
              ),
            ),
            if (active)
              const Icon(LucideIcons.checkCircle2,
                  color: AppColors.bronze, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Security-Tab — Passwort ändern + Recovery-E-Mail-Versand ────────────
class _SecurityTab extends StatefulWidget {
  const _SecurityTab();

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _busy = false;
  bool _show = false;

  @override
  void dispose() {
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final pw = _newPw.text;
    final c = _confirmPw.text;
    if (pw.length < 8) {
      _toast('Passwort muss mindestens 8 Zeichen lang sein.');
      return;
    }
    if (pw != c) {
      _toast('Passwörter stimmen nicht überein.');
      return;
    }
    setState(() => _busy = true);
    try {
      await sb.auth.updateUser(UserAttributes(password: pw));
      if (!mounted) return;
      _newPw.clear();
      _confirmPw.clear();
      _toast('Passwort geändert.');
    } catch (e) {
      _toast('Fehler: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordResetMail() async {
    final email = SupabaseService.currentUser?.email;
    if (email == null) return;
    setState(() => _busy = true);
    try {
      await sb.auth.resetPasswordForEmail(email);
      _toast('Reset-Link an $email gesendet.');
    } catch (_) {
      _toast('Reset-Mail konnte nicht versendet werden.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutAllOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Alle anderen Sessions abmelden?',
            style: AppTypography.body(
                size: 15,
                color: AppColors.ink,
                weight: FontWeight.w700)),
        content: Text(
            'Du bleibst auf diesem Gerät eingeloggt, alle anderen Geräte werden abgemeldet.',
            style:
                AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await sb.auth.signOut(scope: SignOutScope.others);
      _toast('Andere Sessions abgemeldet.');
    } catch (_) {
      _toast('Abmelden fehlgeschlagen.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(msg,
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final email = SupabaseService.currentUser?.email ?? '–';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _label('Angemeldet als'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.mail,
                  size: 16, color: AppColors.mute),
              const SizedBox(width: 8),
              Expanded(
                child: Text(email,
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _label('Passwort ändern'),
        TextField(
          controller: _newPw,
          obscureText: !_show,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: _input('Neues Passwort'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmPw,
          obscureText: !_show,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: _input('Neues Passwort bestätigen'),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Checkbox(
              value: _show,
              onChanged: (v) => setState(() => _show = v ?? false),
              activeColor: AppColors.bronze,
            ),
            Text('Passwort anzeigen',
                style: AppTypography.label(
                    size: 10, color: AppColors.mute)),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _changePassword,
          icon: const Icon(LucideIcons.lock, size: 14),
          label: const Text('Passwort ändern'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.bronze,
            foregroundColor: AppColors.voidColor,
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 28),
        _label('Passwort vergessen'),
        Text(
          'Wenn du dein aktuelles Passwort nicht kennst, senden wir dir einen Reset-Link an deine E-Mail-Adresse.',
          style: AppTypography.body(
              size: 12, color: AppColors.inkSoft, height: 1.5),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _sendPasswordResetMail,
          icon: const Icon(LucideIcons.mail, size: 14),
          label: const Text('Reset-Link senden'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.amber,
            side: BorderSide(
                color: AppColors.amber.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 28),
        _label('Aktive Sessions'),
        Text(
          'Falls du dich auf einem fremden Gerät eingeloggt hast, kannst du alle anderen Sessions hier beenden.',
          style: AppTypography.body(
              size: 12, color: AppColors.inkSoft, height: 1.5),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _signOutAllOtherSessions,
          icon: const Icon(LucideIcons.logOut, size: 14),
          label: const Text('Andere Sessions abmelden'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.herzrot,
            side: BorderSide(
                color: AppColors.herzrot.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 28),
        _label('Zwei-Faktor-Authentisierung'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.shield,
                  size: 16, color: AppColors.mute),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'TOTP-/Authenticator-App-Unterstützung kommt in einem späteren Release.',
                  style: AppTypography.body(
                      size: 12, color: AppColors.inkSoft, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: AppTypography.label(size: 10, color: AppColors.bronze)),
      );

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.body(size: 13, color: AppColors.mute),
      filled: true,
      fillColor: AppColors.elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.bronze),
      ),
    );
  }
}

// ── Language-Tab — manuelle Auswahl + Auto-Detect-Toggle ────────────────
class _LanguageTab extends ConsumerWidget {
  const _LanguageTab();

  static const _flags = <String, String>{
    'de': '🇩🇪',
    'en': '🇬🇧',
    'it': '🇮🇹',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'tr': '🇹🇷',
    'ru': '🇷🇺',
  };

  static const _names = <String, String>{
    'de': 'Deutsch',
    'en': 'English',
    'it': 'Italiano',
    'es': 'Español',
    'fr': 'Français',
    'tr': 'Türkçe',
    'ru': 'Русский',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localeProvider);
    final notifier = ref.read(localeProvider.notifier);
    final isAuto = state.mode == LocaleMode.auto;
    final detectedLang = state.detectedLocale?.languageCode;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('AUTOMATIK',
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: isAuto,
          activeColor: AppColors.bronze,
          onChanged: (v) => notifier.setAuto(v, context),
          title: Text('Sprache nach Standort',
              style: AppTypography.body(
                  size: 14, color: AppColors.ink)),
          subtitle: Text(
            'Die App passt sich an die Sprache des Landes an, in dem du dich befindest.',
            style: AppTypography.body(
                size: 12, color: AppColors.mute, height: 1.4),
          ),
        ),
        if (isAuto && detectedLang != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(_flags[detectedLang] ?? '🌐',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'Aktuell erkannt: ${_names[detectedLang] ?? detectedLang}',
                  style: AppTypography.body(
                      size: 12, color: AppColors.inkSoft),
                ),
                const Spacer(),
                IconButton(
                  iconSize: 16,
                  onPressed: () => notifier.refreshDetected(context),
                  icon: const Icon(LucideIcons.refreshCcw,
                      color: AppColors.bronze),
                  tooltip: 'Neu erkennen',
                ),
              ],
            ),
          ),
        ],
        if (isAuto && detectedLang == null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.herzrot.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle,
                    size: 14, color: AppColors.herzrotWarm),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kein Standort verfügbar — Deutsch wird verwendet.',
                    style: AppTypography.body(
                        size: 12, color: AppColors.inkSoft, height: 1.4),
                  ),
                ),
                IconButton(
                  iconSize: 16,
                  onPressed: () => notifier.refreshDetected(context),
                  icon: const Icon(LucideIcons.refreshCcw,
                      color: AppColors.bronze),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('MANUELL WÄHLEN',
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 8),
        for (final l in kSupportedLocales)
          _LangTile(
            code: l.languageCode,
            flag: _flags[l.languageCode] ?? '🌐',
            name: _names[l.languageCode] ?? l.languageCode,
            active: state.activeLocale.languageCode == l.languageCode,
            disabled: isAuto,
            onTap: () => notifier.setManual(l, context),
          ),
        if (isAuto) ...[
          const SizedBox(height: 8),
          Text(
            'Manuelle Auswahl ist deaktiviert solange Automatik aktiv ist.',
            style: AppTypography.label(size: 10, color: AppColors.mute),
          ),
        ],
      ],
    );
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({
    required this.code,
    required this.flag,
    required this.name,
    required this.active,
    required this.disabled,
    required this.onTap,
  });

  final String code;
  final String flag;
  final String name;
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active
                ? AppColors.bronze.withValues(alpha: 0.15)
                : AppColors.elevated,
            border: Border.all(
              color: active ? AppColors.bronze : AppColors.line,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(name,
                    style: AppTypography.body(
                      size: 14,
                      color: active ? AppColors.bronze : AppColors.ink,
                      weight: active
                          ? FontWeight.w700
                          : FontWeight.w500,
                    )),
              ),
              Text(code.toUpperCase(),
                  style: AppTypography.mono(
                      size: 11, color: AppColors.mute)),
              if (active) ...[
                const SizedBox(width: 8),
                const Icon(LucideIcons.checkCircle2,
                    size: 16, color: AppColors.bronze),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
