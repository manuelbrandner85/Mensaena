import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope, UserAttributes;

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../config/theme/cinema_theme.dart';
import '../../models/profile.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/cinema_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/shorebird_patch_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../repositories/notification_prefs_repository.dart';
import '../../repositories/notifications_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../providers/role_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/device_tier_service.dart';
import '../../services/memory_watchdog_service.dart';
import '../../services/screen_time_service.dart';
import '../../services/sleep_reminder_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/battery_optimization_prompt.dart';
import '../../widgets/shared/release_notes_sheet.dart';
import '../../widgets/shared/app_snackbar.dart';

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
  // Lazy-Loading: nur Tabs die der User mindestens 1x geoeffnet hat
  // werden tatsaechlich gebaut. Spart Renderzeit + Provider-Watch fuer
  // 7 ungenutzte Tabs beim ersten Settings-Open.
  final Set<int> _builtTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 8, vsync: this);
    _tab.addListener(_onTabChanged);
    _future = ProfilesRepository.getMine();
  }

  void _onTabChanged() {
    if (_tab.indexIsChanging) return;
    if (!_builtTabs.contains(_tab.index)) {
      setState(() => _builtTabs.add(_tab.index));
    }
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await ProfilesRepository.update(uid, patch);
    } catch (_) {
      // Vorher still: schlug das Speichern fehl, blieb der Toggle scheinbar
      // gesetzt, war aber nicht persistiert. Jetzt Hinweis + Re-Fetch (zeigt
      // den echten DB-Wert).
      if (mounted) {
        AppSnackBar.error(context, 'settings.saveFailed'.tr());
      }
    }
    if (mounted) setState(() => _future = ProfilesRepository.getMine());
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
                    child: Text('settings.profileNotFound'.tr(),
                        style: AppTypography.caption()),
                  );
                }
                // Lazy-Tabs: jeder Tab ist erst ein SizedBox.shrink()
                // bis der User ihn das erste Mal aufschlaegt. Spart bei
                // First-Open ~7 Tab-Builds + ~5 Provider-Watches.
                final tabs = <Widget>[
                  _AccountTab(profile: p),
                  _PrivacyTab(profile: p, onPatch: _patch),
                  const _SecurityTab(),
                  const _LanguageTab(),
                  _NotifTab(profile: p, onPatch: _patch),
                  _RegionTab(profile: p, onPatch: _patch),
                  const _AppearanceTab(),
                  _DangerTab(),
                ];
                return TabBarView(
                  controller: _tab,
                  children: List.generate(
                    tabs.length,
                    (i) => _builtTabs.contains(i)
                        ? tabs[i]
                        : const SizedBox.shrink(),
                  ),
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
        Text('settings.sections.email'.tr(), style: AppTypography.label(size: 10)),
        const SizedBox(height: 4),
        Text(profile.email ?? '–',
            style: AppTypography.body(size: 14, color: AppColors.ink)),
        const SizedBox(height: 18),
        Text('settings.nameLabel'.tr(), style: AppTypography.label(size: 10)),
        const SizedBox(height: 4),
        Text(profile.name ?? '–',
            style: AppTypography.body(size: 14, color: AppColors.ink)),
        const SizedBox(height: 24),
        Text(
          'settings.editOnWeb'.tr(),
          style: AppTypography.caption(),
        ),
        const SizedBox(height: 24),
        const Divider(color: AppColors.line),
        const SizedBox(height: 12),
        Text('settings.appVersionLabel'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 8),
        const _AppVersionInfo(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => ReleaseNotesSheet.show(context),
          icon: const Icon(LucideIcons.sparkles, size: 14),
          label: Text('releaseNotes.openButton'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.amber,
            side: BorderSide(color: AppColors.amber.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        // F88: Bug-Report via mailto
        OutlinedButton.icon(
          onPressed: () async {
            final info = await PackageInfo.fromPlatform();
            final body =
                '\n\n---\nApp: ${info.version} (${info.buildNumber})\nPlatform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n';
            final uri = Uri(
              scheme: 'mailto',
              path: 'info@mensaena.de',
              query: 'subject=Bug-Report Mensaena App&body=${Uri.encodeComponent(body)}',
            );
            await launchUrl(uri);
          },
          icon: const Icon(LucideIcons.bug, size: 14),
          label: Text('settings.bugReport'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.herzrotWarm,
            side: BorderSide(
                color: AppColors.herzrotWarm.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }
}

/// Info-Zeile mit App-Version + Build-Number + Shorebird-Patch-Nr.
/// Erlaubt Support/User schnell zu sagen welche Version laeuft.
class _AppVersionInfo extends ConsumerWidget {
  const _AppVersionInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patchAsync = ref.watch(currentPatchNumberProvider);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final info = snap.data!;
        final patchStr = patchAsync.when(
          loading: () => '',
          error: (_, __) => '',
          data: (n) => n != null ? ' · Patch #$n' : '',
        );
        final hasPatch = patchAsync.value != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    hasPatch
                        ? LucideIcons.checkCircle2
                        : LucideIcons.info,
                    size: 16,
                    color: hasPatch ? AppColors.leben : AppColors.mute,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'v${info.version} (Build ${info.buildNumber})$patchStr',
                      style:
                          AppTypography.mono(size: 13, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
          label: 'settings.privacy.showOnline'.tr(),
          value: profile.showOnlineStatus,
          onChanged: (v) => onPatch({'show_online_status': v}),
        ),
        _BoolTile(
          label: 'settings.privacy.showLocation'.tr(),
          value: profile.showLocation,
          onChanged: (v) => onPatch({'show_location': v}),
        ),
        _BoolTile(
          label: 'settings.privacy.showTrust'.tr(),
          value: profile.showTrustScore,
          onChanged: (v) => onPatch({'show_trust_score': v}),
        ),
        _BoolTile(
          label: 'settings.privacy.showActivity'.tr(),
          value: profile.showActivity,
          onChanged: (v) => onPatch({'show_activity': v}),
        ),
        _BoolTile(
          label: 'settings.privacy.showPhone'.tr(),
          value: profile.showPhone,
          onChanged: (v) => onPatch({'show_phone': v}),
        ),
        const SizedBox(height: 16),
        Text('settings.profileVisibility'.tr(), style: AppTypography.label(size: 10)),
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
        return 'settings.visibility.public'.tr();
      case 'neighbors':
        return 'settings.visibility.neighbors'.tr();
      case 'private':
        return 'settings.visibility.private'.tr();
      default:
        return v;
    }
  }
}

class _NotifTab extends ConsumerStatefulWidget {
  const _NotifTab({required this.profile, required this.onPatch});
  final Profile profile;
  final Future<void> Function(Map<String, dynamic>) onPatch;

  @override
  ConsumerState<_NotifTab> createState() => _NotifTabState();
}

class _NotifTabState extends ConsumerState<_NotifTab> {
  NotifPrefs? _local;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myNotifPrefsProvider);
    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.amber),
      ),
      error: (e, _) => Center(
        child: Text('settings.errorPrefix'.tr(namedArgs: {'error': e.toString()}), style: AppTypography.caption()),
      ),
      data: (p) {
        _local ??= p;
        final prefs = _local!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('settings.sections.pushNotifications'.tr(),
                style: AppTypography.label(size: 10, color: AppColors.mute)),
            const SizedBox(height: 8),
            _BoolTile(
              label: 'settings.pushEnabled'.tr(),
              value: prefs.enabled,
              onChanged: (v) => _update(prefs.copyWith(enabled: v)),
            ),
            // Hintergrund-Anrufe: jederzeit erreichbarer Setup-Eintrag für
            // Akku-Optimierung / Samsung-Tiefschlaf (der Auto-Prompt zeigt
            // nur einmal — hier kann der Nutzer es nachholen).
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.phoneCall,
                  size: 18, color: AppColors.amber),
              title: Text('settings.bgCalls'.tr(),
                  style: AppTypography.body(size: 14, color: AppColors.ink)),
              subtitle: Text('settings.bgCallsDesc'.tr(),
                  style: AppTypography.body(size: 12, color: AppColors.mute)),
              trailing: const Icon(LucideIcons.chevronRight,
                  size: 16, color: AppColors.mute),
              onTap: () => showBatteryOptimizationSetup(context),
            ),
            // Zentrale Berechtigungs-Übersicht (Kamera/Mikro/Standort/etc.).
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.shieldCheck,
                  size: 18, color: AppColors.bronze),
              title: Text('settings.permissions'.tr(),
                  style: AppTypography.body(size: 14, color: AppColors.ink)),
              subtitle: Text('settings.permissionsDesc'.tr(),
                  style: AppTypography.body(size: 12, color: AppColors.mute)),
              trailing: const Icon(LucideIcons.chevronRight,
                  size: 16, color: AppColors.mute),
              onTap: () =>
                  context.push('/dashboard/settings/permissions'),
            ),
            const SizedBox(height: 18),
            Text('settings.sections.categories'.tr(),
                style: AppTypography.label(size: 10, color: AppColors.mute)),
            const SizedBox(height: 8),
            _BoolTile(
              label: 'settings.notifCat.messages'.tr(),
              value: prefs.chat,
              onChanged: (v) => _update(prefs.copyWith(chat: v)),
            ),
            _BoolTile(
              label: 'settings.notifCat.community'.tr(),
              value: prefs.social,
              onChanged: (v) => _update(prefs.copyWith(social: v)),
            ),
            _BoolTile(
              label: 'settings.notifCat.events'.tr(),
              value: prefs.events,
              onChanged: (v) => _update(prefs.copyWith(events: v)),
            ),
            _BoolTile(
              label: 'settings.notifCat.marketplace'.tr(),
              value: prefs.marketplace,
              onChanged: (v) => _update(prefs.copyWith(marketplace: v)),
            ),
            _BoolTile(
              label: 'settings.notifCat.crisis'.tr(),
              value: prefs.crisis,
              onChanged: (v) => _update(prefs.copyWith(crisis: v)),
            ),
            _BoolTile(
              label: 'settings.notifCat.system'.tr(),
              value: prefs.system,
              onChanged: (v) => _update(prefs.copyWith(system: v)),
            ),
            const SizedBox(height: 18),
            Text('settings.sections.nightMode'.tr(),
                style: AppTypography.label(size: 10, color: AppColors.mute)),
            const SizedBox(height: 8),
            _BoolTile(
              label: 'settings.notif.quietEnable'.tr(),
              value: prefs.quietHoursEnabled,
              onChanged: (v) =>
                  _update(prefs.copyWith(quietHoursEnabled: v)),
            ),
            if (prefs.quietHoursEnabled) ...[
              const SizedBox(height: 4),
              _HourRow(
                label: 'settings.notif.quietFrom'.tr(),
                value: prefs.quietStartHour,
                onChanged: (h) =>
                    _update(prefs.copyWith(quietStartHour: h)),
              ),
              _HourRow(
                label: 'settings.notif.quietTo'.tr(),
                value: prefs.quietEndHour,
                onChanged: (h) =>
                    _update(prefs.copyWith(quietEndHour: h)),
              ),
              const SizedBox(height: 4),
              _BoolTile(
                label: 'settings.notif.quietAllowCritical'.tr(),
                value: prefs.quietAllowCritical,
                onChanged: (v) =>
                    _update(prefs.copyWith(quietAllowCritical: v)),
              ),
            ],
            const SizedBox(height: 18),
            Text('settings.sections.dailySummary'.tr(),
                style: AppTypography.label(size: 10, color: AppColors.mute)),
            const SizedBox(height: 8),
            _BoolTile(
              label: 'settings.notif.digestEnable'.tr(),
              value: prefs.dailyDigestEnabled,
              onChanged: (v) =>
                  _update(prefs.copyWith(dailyDigestEnabled: v)),
            ),
            if (prefs.dailyDigestEnabled)
              _HourRow(
                label: 'settings.notif.digestHour'.tr(),
                value: prefs.dailyDigestHour,
                onChanged: (h) =>
                    _update(prefs.copyWith(dailyDigestHour: h)),
              ),
            const SizedBox(height: 18),
            const _NotifPushPrefsSection(),
            const SizedBox(height: 18),
            // F44: Benachrichtigungs-Radius für nearby-Posts.
            Text('notif.radiusSection'.tr().toUpperCase(),
                style: AppTypography.label(size: 10, color: AppColors.mute)),
            const SizedBox(height: 8),
            _NotifyRadiusRow(),
            const SizedBox(height: 24),
            // DSGVO-Opt-out: Marketing + Reaktivierung (eigene profiles-Spalten).
            Text('privacy_prefs.section'.tr().toUpperCase(),
                style: AppTypography.label(size: 10, color: AppColors.mute)),
            const SizedBox(height: 8),
            const _MarketingPrefsSection(),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _sendTestNotification,
              icon: const Icon(LucideIcons.bellRing, size: 16),
              label: Text('notif.send_test'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bronze,
                side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'settings.profileSettingsHint'.tr(),
              style: AppTypography.caption(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _update(NotifPrefs next) async {
    setState(() => _local = next);
    await NotificationPrefsRepository.save(next);
    ref.invalidate(myNotifPrefsProvider);
  }

  Future<void> _sendTestNotification() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await NotificationsRepository.insertSelfTest(
        title: 'notif.test_title'.tr(),
        message: 'notif.test_body'.tr(),
      );
      if (!mounted) return;
      AppSnackBar.success(context, 'notif.test_sent'.tr());
    } catch (_) {}
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: AppTypography.body(size: 13, color: AppColors.ink)),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 23,
              divisions: 23,
              activeColor: AppColors.bronze,
              inactiveColor: AppColors.line,
              label: '${value.toString().padLeft(2, '0')}:00',
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${value.toString().padLeft(2, '0')}:00',
              textAlign: TextAlign.right,
              style: AppTypography.mono(size: 13, color: AppColors.bronze),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionTab extends StatefulWidget {
  const _RegionTab({required this.profile, required this.onPatch});
  final Profile profile;
  final Future<void> Function(Map<String, dynamic>) onPatch;

  @override
  State<_RegionTab> createState() => _RegionTabState();
}

class _RegionTabState extends State<_RegionTab> {
  late double _radius = (widget.profile.radiusKm ?? 10).toDouble();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('settings.locationLabel'.tr(), style: AppTypography.label(size: 10)),
        const SizedBox(height: 4),
        Text(
          widget.profile.location ?? 'Nicht gesetzt',
          style: AppTypography.body(size: 14, color: AppColors.ink),
        ),
        const SizedBox(height: 18),
        Text('settings.radiusKm'.tr(namedArgs: {'km': _radius.toInt().toString()}),
            style: AppTypography.label(size: 10)),
        Slider(
          activeColor: AppColors.amber,
          inactiveColor: AppColors.elevated,
          value: _radius,
          min: 1,
          max: 150,
          divisions: 149,
          // Live-Feedback während des Ziehens (vorher: leeres onChanged →
          // Regler bewegte sich erst beim Loslassen). Persistiert in onChangeEnd.
          onChanged: (v) => setState(() => _radius = v),
          onChangeEnd: (v) => widget.onPatch({'radius_km': v.toInt()}),
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
      // Vollständiger, fehler-toleranter Export (GDPR Art. 20). Vorher:
      // nur 9 Tabellen, badges mit limit(0) (immer leer), und ein einziger
      // Future.wait → schlug eine Query fehl, brach der ganze Export ab.
      // Jetzt: pro Tabelle eigener try/catch, fehlende Tabelle = leer.
      const single = <String, String>{
        'profiles': 'id',
        'posts': 'user_id',
        'post_comments': 'user_id',
        'board_posts': 'author_id',
        'messages': 'sender_id',
        'notifications': 'user_id',
        'saved_posts': 'user_id',
        'badges': 'user_id',
        'karma_log': 'user_id',
        'event_attendees': 'user_id',
        'group_members': 'user_id',
        'marketplace_listings': 'user_id',
        'community_poll_votes': 'user_id',
        // DSGVO Art. 20 — Vervollständigung: Kommunikation, Matching, Krisen,
        // E-Mail-Engagement, Geräte, Einwilligungs-Historie.
        'conversation_members': 'user_id',
        'match_preferences': 'user_id',
        'crisis_helpers': 'user_id',
        'crisis_updates': 'user_id',
        'user_blocks': 'blocker_id',
        'email_subscriptions': 'user_id',
        'email_logs': 'user_id',
        'fcm_tokens': 'user_id',
        'push_subscriptions': 'user_id',
        'user_notification_prefs': 'user_id',
        'consents': 'user_id',
      };
      // Tabellen mit zwei beteiligten Spalten (beide Richtungen exportieren).
      const dual = <String, String>{
        'interactions': 'helper_id,helped_id',
        'trust_ratings': 'rater_id,rated_id',
        'matches': 'offer_user_id,request_user_id',
        'dm_calls': 'caller_id,callee_id',
      };
      final collected = <String, dynamic>{};
      await Future.wait([
        for (final e in single.entries)
          () async {
            collected[e.key] =
                await SettingsRepository.gdprRowsSingle(e.key, e.value, uid);
          }(),
        for (final e in dual.entries)
          () async {
            final cols = e.value.split(',');
            collected[e.key] = await SettingsRepository.gdprRowsDual(
                e.key, cols[0], cols[1], uid);
          }(),
      ]);
      final profileRows = collected['profiles'] as List? ?? const [];
      final exportData = <String, dynamic>{
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'user_id': uid,
        'note':
            'Mensaena GDPR Article 20 Export — Right to Data Portability',
        ...collected,
        'profile': profileRows.isNotEmpty ? profileRows.first : null,
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
      AppSnackBar.info(context, 'settings.exportCreated'.tr(namedArgs: {'size': (json.length / 1024).toStringAsFixed(1)}));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'settings.exportFailed'.tr(namedArgs: {'error': e.toString()}));
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
        title: Text('settings.deleteAccountTitle'.tr(),
            style: AppTypography.body(
                size: 16, color: AppColors.ink, weight: FontWeight.w700)),
        content: Text(
          'settings.deleteWarning'.tr(),
          style: AppTypography.body(
              size: 13, color: AppColors.inkSoft, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: Text('settings.continueToConfirm'.tr()),
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
      // Account-Delete ist irreversibel — JWT muss frisch sein, sonst
      // schlaegt RPC fehl bei abgelaufenem Token.
      await SupabaseService.ensureFreshSession();
      // ECHTE Löschung via delete_my_account-RPC: löscht auth.users →
      // CASCADE entfernt Profil + alle Inhalte. KEIN stiller Soft-Delete-
      // Fallback mehr — der täuschte dem Nutzer eine Löschung vor, während
      // Posts/Nachrichten erhalten blieben (GDPR-Verstoß). Schlägt die RPC
      // fehl, wird der Fehler angezeigt und der Account NICHT abgemeldet.
      await sb.rpc<dynamic>('delete_my_account');
      await sb.auth.signOut();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      AppSnackBar.error(context, 'settings.deleteFailed'.tr(namedArgs: {'error': e.toString()}));
    }
  }

  Future<bool?> _showTypedConfirmation() {
    final ctrl = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final word = 'settings.deleteConfirmWord'.tr();
          final canDelete = ctrl.text.trim() == word;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('settings.finalConfirmTitle'.tr(),
                style: AppTypography.body(
                    size: 16,
                    color: AppColors.ink,
                    weight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'settings.deleteTypePrompt'.tr(namedArgs: {'word': word}),
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
                  decoration: InputDecoration(
                    hintText: word,
                    filled: true,
                    fillColor: AppColors.elevated,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('common.cancel'.tr())),
              TextButton(
                onPressed: canDelete ? () => Navigator.pop(ctx, true) : null,
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.herzrot),
                child: Text('settings.deleteAccountFinal'.tr()),
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
        Text('settings.sections.session'.tr(), style: AppTypography.label(size: 10)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final ok = await ConfirmDialog.show(
              context,
              title: 'common.logoutConfirmTitle'.tr(),
              message: 'common.logoutConfirmBody'.tr(),
              confirmLabel: 'common.logout'.tr(),
              danger: true,
            );
            if (!ok || !context.mounted) return;
            await sb.auth.signOut();
            if (context.mounted) context.go('/');
          },
          icon: const Icon(LucideIcons.logOut, size: 16),
          label: Text('common.logout'.tr()),
        ),
        const SizedBox(height: 24),
        Text('settings.sections.privacyGdpr'.tr(), style: AppTypography.label(size: 10)),
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
              ? 'settings.exporting'.tr()
              : 'settings.exportData'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.amber,
            side: BorderSide(color: AppColors.amber.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(height: 24),
        Text('settings.sections.dangerZone'.tr(), style: AppTypography.label(size: 10)),
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
                'settings.deleteAccountHeading'.tr(),
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.herzrotWarm,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'settings.deleteAccountDesc'.tr(),
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
                      ? 'settings.deleting'.tr()
                      : 'settings.deleteAccountBtn'.tr()),
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
        // V20 Phase-6b: Theme-Mode (Dark/Light/System) am oberen Rand.
        Text('settings.themeMode.label'.tr().toUpperCase(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 8),
        const _ThemeModeRow(),
        const SizedBox(height: 20),
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
                  Text('settings.sections.currentMood'.tr(),
                      style: AppTypography.label(
                          size: 9, color: AppColors.bronzeSoft)),
                ],
              ),
              const SizedBox(height: 8),
              if (spec == null)
                Text('settings.themeOff'.tr(),
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
                          Text('settings.themeActive'.tr(),
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
        Text('settings.sections.cinemaMode'.tr(),
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
        Text('settings.sections.effectStrength'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 8),
        _IntensityTiles(),
        const SizedBox(height: 12),
        const _ForceFullEffectsToggle(),
        const SizedBox(height: 16),
        Text('settings.sections.sound'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 4),
        const _SoundToggle(),
        const SizedBox(height: 12),
        // Punkt 7: Anruf-Ton & Lautstärke.
        Text('settings.sections.callSound'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 4),
        const _CallSoundSection(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.go('/onboarding'),
          icon: const Icon(LucideIcons.play, size: 14),
          label: Text('settings.replayOnboarding'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(
                color: AppColors.bronze.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 16),
        Text('a11y.section'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 4),
        const _A11ySection(),
        const SizedBox(height: 16),
        Text('detox.section'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 4),
        const _DetoxSection(),
        const SizedBox(height: 16),
        Text('sleep_reminder.section'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 4),
        const _SleepReminderSection(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push('/dashboard/account'),
          icon: const Icon(LucideIcons.userCog, size: 16),
          label: Text('account.title'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/dashboard/karma-history'),
          icon: const Icon(LucideIcons.history, size: 16),
          label: Text('karma.history_title'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/dashboard/mentorship'),
          icon: const Icon(LucideIcons.users, size: 16),
          label: Text('mentorship.title'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/dashboard/scheduled-calls'),
          icon: const Icon(LucideIcons.phoneCall, size: 16),
          label: Text('scheduled_calls.title'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/dashboard/my-drafts'),
          icon: const Icon(LucideIcons.fileText, size: 16),
          label: Text('posts.drafts'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/dashboard/voicemail'),
          icon: const Icon(LucideIcons.voicemail, size: 16),
          label: Text('voicemail.title'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/dashboard/live/scheduled'),
          icon: const Icon(LucideIcons.calendarClock, size: 16),
          label: Text('live.scheduled_title'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        Consumer(
          builder: (_, ref, __) {
            final role = ref.watch(userRoleProvider) ?? 'user';
            if (role != 'admin' &&
                role != 'super_admin' &&
                role != 'moderator') {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/dashboard/admin/crash-logs'),
                icon: const Icon(LucideIcons.bug, size: 16),
                label: Text('admin.crash_logs'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.herzrotWarm,
                  side: BorderSide(
                      color: AppColors.herzrotWarm.withValues(alpha: 0.5)),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // MEMORY: Manueller Bild-/Cache-Reset. Hilft bei subjektiver
        // Langsamkeit nach langer Nutzung, ohne die App neu zu starten.
        Text('settings.sections.storage'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () {
            final freedMb = MemoryWatchdogService.instance.clearAll();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('settings.clearCacheDone'.tr(
                  namedArgs: {'mb': freedMb.toStringAsFixed(1)})),
            ));
          },
          icon: const Icon(LucideIcons.trash2, size: 16),
          label: Text('settings.clearCache'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(color: AppColors.bronze.withValues(alpha: 0.5)),
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
                  Text('settings.whatIsThis'.tr(),
                      style: AppTypography.label(
                          size: 10, color: AppColors.mute)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'settings.cinemaExplain'.tr(),
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

/// Theme-Mode-Auswahl (System / Hell / Dunkel) als SegmentedButton.
class _ThemeModeRow extends ConsumerWidget {
  const _ThemeModeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final entries = <(ThemeMode, IconData, String)>[
      (ThemeMode.system, LucideIcons.smartphone, 'settings.themeMode.system'),
      (ThemeMode.light, LucideIcons.sun, 'settings.themeMode.light'),
      (ThemeMode.dark, LucideIcons.moon, 'settings.themeMode.dark'),
    ];
    return Row(
      children: [
        for (final e in entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () =>
                    ref.read(themeModeProvider.notifier).set(e.$1),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: current == e.$1
                        ? AppColors.amber.withValues(alpha: 0.18)
                        : AppColors.elevated,
                    border: Border.all(
                      color: current == e.$1
                          ? AppColors.amber
                          : AppColors.line,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        e.$2,
                        size: 16,
                        color: current == e.$1
                            ? AppColors.amber
                            : AppColors.inkSoft,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.$3.tr(),
                        style: AppTypography.body(
                          size: 11,
                          color: current == e.$1
                              ? AppColors.amber
                              : AppColors.inkSoft,
                          weight: current == e.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      title: Text('settings.sections.uiSounds'.tr(),
          style: AppTypography.body(size: 14, color: AppColors.ink)),
      subtitle: Text(
        'settings.uiSoundsDesc'.tr(),
        style: AppTypography.body(size: 12, color: AppColors.mute),
      ),
    );
  }
}

/// Punkt 7: Klingelton-Lautstärke (Slider) + Anruf-Vibration (Toggle).
class _CallSoundSection extends StatefulWidget {
  const _CallSoundSection();

  @override
  State<_CallSoundSection> createState() => _CallSoundSectionState();
}

class _CallSoundSectionState extends State<_CallSoundSection> {
  double _ringVolume = 0.6;
  bool _vibration = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.wait([
      SoundService.ringVolume(),
      SoundService.callVibration(),
    ]).then((vals) {
      if (!mounted) return;
      setState(() {
        _ringVolume = vals[0] as double;
        _vibration = vals[1] as bool;
        _loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.bronze),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _ringVolume == 0
                  ? LucideIcons.volumeX
                  : LucideIcons.volume2,
              size: 16,
              color: AppColors.bronze,
            ),
            const SizedBox(width: 8),
            Text('settings.callSound.ringVolume'.tr(),
                style: AppTypography.body(size: 13, color: AppColors.ink)),
            const Spacer(),
            Text('${(_ringVolume * 100).round()}%',
                style: AppTypography.mono(size: 11, color: AppColors.mute)),
          ],
        ),
        Slider.adaptive(
          value: _ringVolume,
          activeColor: AppColors.bronze,
          onChanged: (v) => setState(() => _ringVolume = v),
          onChangeEnd: (v) => SoundService.setRingVolume(v),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _vibration,
          activeColor: AppColors.bronze,
          onChanged: (next) async {
            await SoundService.setCallVibration(next);
            if (mounted) setState(() => _vibration = next);
          },
          title: Text('settings.callSound.vibration'.tr(),
              style: AppTypography.body(size: 14, color: AppColors.ink)),
        ),
      ],
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

/// „Maximale Kino-Effekte erzwingen" — entsperrt die vollen Effekte auch auf
/// als schwach erkannten Geräten (Override des Lite-Mode + Watchdog-Deckels).
class _ForceFullEffectsToggle extends ConsumerWidget {
  const _ForceFullEffectsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(forceFullEffectsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: on ? AppColors.amber : AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.palette,
              size: 18, color: on ? AppColors.amber : AppColors.mute),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('settings.forceFullEffects.label'.tr(),
                    style: AppTypography.body(size: 14, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text('settings.forceFullEffects.hint'.tr(),
                    style: AppTypography.caption()),
              ],
            ),
          ),
          Switch.adaptive(
            value: on,
            activeColor: AppColors.amber,
            onChanged: (v) =>
                ref.read(forceFullEffectsProvider.notifier).set(v),
          ),
        ],
      ),
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
        return 'settings.cinemaDesc.auto'.tr();
      case CinemaMode.off:
        return 'settings.cinemaDesc.off'.tr();
      case CinemaMode.forceNight:
        return 'settings.cinemaDesc.night'.tr();
      case CinemaMode.forceDay:
        return 'settings.cinemaDesc.day'.tr();
      case CinemaMode.forceDusk:
        return 'settings.cinemaDesc.dusk'.tr();
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
      _toast('settings.pwTooShort'.tr());
      return;
    }
    if (pw != c) {
      _toast('settings.pwMismatch'.tr());
      return;
    }
    setState(() => _busy = true);
    try {
      await sb.auth.updateUser(UserAttributes(password: pw));
      if (!mounted) return;
      _newPw.clear();
      _confirmPw.clear();
      _toast('settings.pwChanged'.tr());
    } catch (e) {
      _toast('settings.errorPrefix'.tr(namedArgs: {'error': '$e'}));
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
      _toast('settings.resetLinkSent'.tr(namedArgs: {'email': email}));
    } catch (_) {
      _toast('settings.resetMailFailed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOutAllOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('settings.signOutOtherSessions'.tr(),
            style: AppTypography.body(
                size: 15,
                color: AppColors.ink,
                weight: FontWeight.w700)),
        content: Text(
            'settings.signOutOthersDesc'.tr(),
            style:
                AppTypography.body(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.herzrot),
            child: Text('common.logout'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await sb.auth.signOut(scope: SignOutScope.others);
      _toast('settings.otherSessionsSignedOut'.tr());
    } catch (_) {
      _toast('settings.signOutFailed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    AppSnackBar.info(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final email = SupabaseService.currentUser?.email ?? '–';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _label('settings.loggedInAs'.tr()),
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
        _label('settings.changePassword'.tr()),
        TextField(
          controller: _newPw,
          obscureText: !_show,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: _input('settings.newPassword'.tr()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _confirmPw,
          obscureText: !_show,
          style: AppTypography.body(size: 14, color: AppColors.ink),
          decoration: _input('settings.confirmNewPassword'.tr()),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Checkbox(
              value: _show,
              onChanged: (v) => setState(() => _show = v ?? false),
              activeColor: AppColors.bronze,
            ),
            Text('settings.showPassword'.tr(),
                style: AppTypography.label(
                    size: 10, color: AppColors.mute)),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _changePassword,
          icon: const Icon(LucideIcons.lock, size: 14),
          label: Text('settings.changePassword'.tr()),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.bronze,
            foregroundColor: AppColors.voidColor,
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 28),
        _label('settings.forgotPassword'.tr()),
        Text(
          'settings.forgotPasswordDesc'.tr(),
          style: AppTypography.body(
              size: 12, color: AppColors.inkSoft, height: 1.5),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _sendPasswordResetMail,
          icon: const Icon(LucideIcons.mail, size: 14),
          label: Text('settings.sendResetLink'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.amber,
            side: BorderSide(
                color: AppColors.amber.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 28),
        _label('settings.activeSessions'.tr()),
        Text(
          'settings.activeSessionsDesc'.tr(),
          style: AppTypography.body(
              size: 12, color: AppColors.inkSoft, height: 1.5),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _signOutAllOtherSessions,
          icon: const Icon(LucideIcons.logOut, size: 14),
          label: Text('settings.signOutOthersBtn'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.herzrot,
            side: BorderSide(
                color: AppColors.herzrot.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 28),
        const _BiometricSection(),
        const SizedBox(height: 28),
        _label('settings.twoFactor'.tr()),
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
                  'settings.twoFactorComing'.tr(),
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
        Text('settings.sections.automatic'.tr(),
            style: AppTypography.label(size: 10, color: AppColors.mute)),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: isAuto,
          activeColor: AppColors.bronze,
          onChanged: (v) => notifier.setAuto(v, context),
          title: Text('settings.languageByLocation'.tr(),
              style: AppTypography.body(
                  size: 14, color: AppColors.ink)),
          subtitle: Text(
            'settings.languageByLocationDesc'.tr(),
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
                  'settings.detectedNow'.tr(namedArgs: {
                    'lang': _names[detectedLang] ?? detectedLang
                  }),
                  style: AppTypography.body(
                      size: 12, color: AppColors.inkSoft),
                ),
                const Spacer(),
                IconButton(
                  iconSize: 16,
                  onPressed: () => notifier.refreshDetected(context),
                  icon: const Icon(LucideIcons.refreshCcw,
                      color: AppColors.bronze),
                  tooltip: 'settings.tooltipDetectAgain'.tr(),
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
                    'settings.noLocationFallback'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.inkSoft, height: 1.4),
                  ),
                ),
                IconButton(
                  tooltip: 'common.refresh'.tr(),
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
        Text('settings.sections.chooseManually'.tr(),
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

class _DetoxSection extends StatefulWidget {
  const _DetoxSection();

  @override
  State<_DetoxSection> createState() => _DetoxSectionState();
}

class _DetoxSectionState extends State<_DetoxSection> {
  bool _enabled = true;
  int _thresholdMin = 60;
  int _todayMin = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final en = await ScreenTimeService.isEnabled();
    final th = await ScreenTimeService.getThresholdMin();
    final today = await ScreenTimeService.getTodayMinutes();
    if (!mounted) return;
    setState(() {
      _enabled = en;
      _thresholdMin = th;
      _todayMin = today;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.leaf,
                  size: 16, color: AppColors.leben),
              const SizedBox(width: 8),
              Expanded(
                child: Text('detox.toggleTitle'.tr(),
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w600)),
              ),
              Switch(
                value: _enabled,
                activeColor: AppColors.leben,
                onChanged: (v) async {
                  await ScreenTimeService.setEnabled(v);
                  if (mounted) setState(() => _enabled = v);
                },
              ),
            ],
          ),
          if (_enabled) ...[
            const SizedBox(height: 6),
            Text(
              'detox.thresholdLabel'
                  .tr(namedArgs: {'min': '$_thresholdMin'}),
              style: AppTypography.body(
                  size: 12, color: AppColors.inkSoft),
            ),
            Slider(
              value: _thresholdMin.toDouble(),
              min: 15,
              max: 180,
              divisions: 11,
              activeColor: AppColors.leben,
              onChanged: (v) =>
                  setState(() => _thresholdMin = v.round()),
              onChangeEnd: (v) =>
                  ScreenTimeService.setThresholdMin(v.round()),
            ),
            const SizedBox(height: 4),
            Text(
              'detox.todayUsed'.tr(namedArgs: {'min': '$_todayMin'}),
              style: AppTypography.caption(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// F15 Biometric: Fingerprint/Face-Lock fuer App-Start.
// ─────────────────────────────────────────────────────────────
class _BiometricSection extends StatefulWidget {
  const _BiometricSection();

  @override
  State<_BiometricSection> createState() => _BiometricSectionState();
}

class _BiometricSectionState extends State<_BiometricSection> {
  bool _supported = false;
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supported = await BiometricService.canAuthenticate();
    final enabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool v) async {
    if (v) {
      // Vor dem Aktivieren: einmal authentifizieren — sonst koennte ein
      // Fremder den Switch hier flippen.
      final ok = await BiometricService.authenticate(
        reason: 'biometric.activateReason'.tr(),
      );
      if (!ok) return;
    }
    await BiometricService.setEnabled(v);
    if (!mounted) return;
    setState(() => _enabled = v);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fingerprint,
                  size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'biometric.section'.tr(),
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              if (_supported)
                Switch(
                  value: _enabled,
                  onChanged: _toggle,
                  activeColor: AppColors.bronze,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _supported
                ? 'biometric.subtitle'.tr()
                : 'biometric.unsupported'.tr(),
            style: AppTypography.body(
                size: 12, color: AppColors.inkSoft, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// P11 Sleep-Reminder: täglich um gewählte Uhrzeit lokal benachrichtigen.
// ─────────────────────────────────────────────────────────────
class _SleepReminderSection extends StatefulWidget {
  const _SleepReminderSection();
  @override
  State<_SleepReminderSection> createState() => _SleepReminderSectionState();
}

class _SleepReminderSectionState extends State<_SleepReminderSection> {
  bool _enabled = false;
  int _hour = 22;
  int _minute = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await SleepReminderService.instance.isEnabled();
    final t = await SleepReminderService.instance.currentTime();
    if (!mounted) return;
    setState(() {
      _enabled = on;
      _hour = t.hour;
      _minute = t.minute;
      _loaded = true;
    });
  }

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    if (v) {
      await SleepReminderService.instance
          .enable(hour: _hour, minute: _minute);
    } else {
      await SleepReminderService.instance.disable();
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (t == null) return;
    setState(() {
      _hour = t.hour;
      _minute = t.minute;
    });
    if (_enabled) {
      await SleepReminderService.instance
          .enable(hour: _hour, minute: _minute);
    }
  }

  String get _timeLabel =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _toggle,
          activeColor: AppColors.bronze,
          title: Text('sleep_reminder.enable'.tr(),
              style: AppTypography.body(size: 14, color: AppColors.ink)),
          subtitle: Text(
            'sleep_reminder.time_label'
                .tr(namedArgs: {'time': _timeLabel}),
            style: AppTypography.caption(),
          ),
        ),
        TextButton.icon(
          onPressed: _pickTime,
          icon: const Icon(LucideIcons.clock, size: 14),
          label: Text('sleep_reminder.pick_time'.tr()),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// F20 Accessibility-Suite: TextScale, Reduce-Motion, High-Contrast.
// ─────────────────────────────────────────────────────────────
class _A11ySection extends ConsumerWidget {
  const _A11ySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a11y = ref.watch(a11yProvider);
    final notifier = ref.read(a11yProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TextScale
          Row(
            children: [
              const Icon(LucideIcons.type,
                  size: 16, color: AppColors.bronze),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'a11y.textScale'
                      .tr(namedArgs: {
                    'pct': (a11y.textScale * 100).round().toString(),
                  }),
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: a11y.textScale,
            min: 0.85,
            max: 1.3,
            divisions: 9,
            activeColor: AppColors.bronze,
            label: '${(a11y.textScale * 100).round()}%',
            onChanged: (v) => notifier.setTextScale(v),
          ),
          const SizedBox(height: 8),
          // Reduce Motion
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: a11y.reduceMotion,
            onChanged: notifier.setReduceMotion,
            activeColor: AppColors.bronze,
            title: Text('a11y.reduceMotion'.tr(),
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.ink,
                  weight: FontWeight.w600,
                )),
            subtitle: Text('a11y.reduceMotionHint'.tr(),
                style: AppTypography.caption()),
          ),
          const SizedBox(height: 4),
          // Performance-Modus (Lite/Standard/Auto) — siehe DeviceTierService.
          const _PerformanceModeRow(),
          const SizedBox(height: 4),
          // High Contrast
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: a11y.highContrast,
            onChanged: notifier.setHighContrast,
            activeColor: AppColors.bronze,
            title: Text('a11y.highContrast'.tr(),
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.ink,
                  weight: FontWeight.w600,
                )),
            subtitle: Text('a11y.highContrastHint'.tr(),
                style: AppTypography.caption()),
          ),
          const SizedBox(height: 4),
          // F83 OLED Dark Mode
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: a11y.oledMode,
            onChanged: notifier.setOledMode,
            activeColor: AppColors.bronze,
            title: Text('a11y.oledMode'.tr(),
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.ink,
                  weight: FontWeight.w600,
                )),
            subtitle: Text('a11y.oledModeHint'.tr(),
                style: AppTypography.caption()),
          ),
          const SizedBox(height: 4),
          // F53 Senior-Mode
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: a11y.seniorMode,
            onChanged: notifier.setSeniorMode,
            activeColor: AppColors.bronze,
            title: Text('a11y.seniorMode'.tr(),
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.ink,
                  weight: FontWeight.w600,
                )),
            subtitle: Text('a11y.seniorModeHint'.tr(),
                style: AppTypography.caption()),
          ),
        ],
      ),
    );
  }
}

/// F44: Slider + Toggle für Benachrichtigungs-Radius (km).
class _NotifyRadiusRow extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NotifyRadiusRow> createState() => _NotifyRadiusRowState();
}

class _NotifyRadiusRowState extends ConsumerState<_NotifyRadiusRow> {
  double? _radius;
  bool? _enabled;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final pAsync = ref.watch(myProfileProvider);
    return pAsync.when(
      loading: () => const SizedBox(height: 60),
      error: (_, __) => const SizedBox.shrink(),
      data: (p) {
        _radius ??= (p?.notificationRadiusKm ?? 10).toDouble();
        _enabled ??= p?.notifyNearbyPosts ?? true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BoolTile(
              label: 'notif.nearbyToggle'.tr(),
              value: _enabled!,
              onChanged: (v) async {
                setState(() => _enabled = v);
                await _save();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.target,
                    size: 14, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text(
                  'notif.radiusValue'
                      .tr(namedArgs: {'km': _radius!.toStringAsFixed(0)}),
                  style: AppTypography.body(
                      size: 13, color: AppColors.ink),
                ),
                const Spacer(),
                if (_saving)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.bronze),
                  ),
              ],
            ),
            Slider(
              value: _radius!,
              min: 1,
              max: 50,
              divisions: 49,
              activeColor: AppColors.bronze,
              onChanged: _enabled!
                  ? (v) => setState(() => _radius = v)
                  : null,
              onChangeEnd: _enabled! ? (_) => _save() : null,
            ),
            Text('notif.radiusHint'.tr(),
                style: AppTypography.caption()),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ProfilesRepository.update(uid, {
        'notification_radius_km': _radius!.toInt(),
        'notify_nearby_posts': _enabled,
      });
      ref.invalidate(myProfileProvider);
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }
}

/// Lite-Mode-Toggle: Auto / An / Aus. Auto-Detection erkennt ARM32 +
/// Android < 9 als „lite". Override persistiert in SecureStorage und
/// gewinnt über die Auto-Detection.
class _PerformanceModeRow extends ConsumerWidget {
  const _PerformanceModeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(deviceTierProvider);
    return infoAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        final isLite = info.tier == DeviceTier.lite;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text('a11y.performanceMode'.tr(),
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.ink,
                    weight: FontWeight.w600,
                  )),
            ),
            Text('a11y.liteHint'.tr(),
                style: AppTypography.caption()),
            const SizedBox(height: 8),
            SegmentedButton<DeviceTier?>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: null,
                  label: Text('a11y.liteAuto'.tr()),
                ),
                ButtonSegment(
                  value: DeviceTier.lite,
                  label: Text('a11y.liteOn'.tr()),
                ),
                ButtonSegment(
                  value: DeviceTier.standard,
                  label: Text('a11y.liteOff'.tr()),
                ),
              ],
              selected: <DeviceTier?>{info.overridden ? info.tier : null},
              onSelectionChanged: (set) async {
                await DeviceTierService.setOverride(set.first);
                ref.invalidate(deviceTierProvider);
              },
            ),
            const SizedBox(height: 6),
            if (isLite && !info.overridden)
              Text('a11y.liteAutoDetected'.tr(),
                  style: AppTypography.caption()),
            if (info.overridden)
              Text('a11y.liteOverrideHint'.tr(),
                  style: AppTypography.caption()),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// DSGVO-Marketing/Reaktivierungs-Opt-out — schreibt direkt in profiles.
class _MarketingPrefsSection extends StatefulWidget {
  const _MarketingPrefsSection();
  @override
  State<_MarketingPrefsSection> createState() => _MarketingPrefsSectionState();
}

class _MarketingPrefsSectionState extends State<_MarketingPrefsSection> {
  bool _loading = true;
  bool _marketing = false;
  bool _reactivation = false;
  bool _email = false;
  bool _emailBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final flags = await SettingsRepository.getConsentFlags(uid);
      if (!mounted) return;
      setState(() {
        _marketing = flags.marketing;
        _reactivation = flags.reactivation;
        _email = flags.email;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// E-Mail-Newsletter: Einschalten löst Double-Opt-in aus (Bestätigungs-Mail);
  /// das Abo wird erst nach dem Klick im Postfach aktiv. Ausschalten widerruft
  /// sofort.
  Future<void> _toggleEmail(bool v) async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _emailBusy = true);
    try {
      if (v) {
        await sb.functions.invoke('request-email-optin');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('privacy_prefs.emailConfirmSent'.tr()),
        ));
        // Bleibt aus, bis im Postfach bestätigt wurde.
        setState(() => _email = false);
      } else {
        await ProfilesRepository.update(uid, {'email_opt_in': false});
        await SettingsRepository.unsubscribeEmail(uid);
        await sb.rpc<dynamic>('record_consent', params: {
          'p_type': 'email',
          'p_granted': false,
          'p_source': 'settings',
        });
        if (mounted) setState(() => _email = false);
      }
    } catch (_) {
      if (mounted) _load();
    } finally {
      if (mounted) setState(() => _emailBusy = false);
    }
  }

  Future<void> _set(String col, bool v) async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    setState(() {
      if (col == 'marketing_opt_in') _marketing = v;
      if (col == 'reactivation_opt_in') _reactivation = v;
    });
    try {
      await ProfilesRepository.update(uid, {col: v});
      // DSGVO Art. 7(1): Einwilligung/Widerruf revisionssicher protokollieren.
      final type = col == 'marketing_opt_in' ? 'marketing' : 'reactivation';
      await sb.rpc<dynamic>('record_consent', params: {
        'p_type': type,
        'p_granted': v,
        'p_source': 'settings',
      });
    } catch (_) {
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Column(
      children: [
        _BoolTile(
          label: 'privacy_prefs.marketing'.tr(),
          value: _marketing,
          onChanged: (v) => _set('marketing_opt_in', v),
        ),
        _BoolTile(
          label: 'privacy_prefs.reactivation'.tr(),
          value: _reactivation,
          onChanged: (v) => _set('reactivation_opt_in', v),
        ),
        _BoolTile(
          label: 'privacy_prefs.email'.tr(),
          value: _email,
          onChanged: (v) {
            if (!_emailBusy) _toggleEmail(v);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('privacy_prefs.hint'.tr(),
              style: AppTypography.caption()),
        ),
      ],
    );
  }
}

// ── Push-Benachrichtigungen Kategorien (JSONB in profiles) ───────────────
/// 5 Feature-Kategorien-Toggles, gespeichert als notification_preferences
/// JSONB im profiles-Datensatz via SettingsRepository.
class _NotifPushPrefsSection extends ConsumerStatefulWidget {
  const _NotifPushPrefsSection();

  @override
  ConsumerState<_NotifPushPrefsSection> createState() =>
      _NotifPushPrefsSectionState();
}

class _NotifPushPrefsSectionState
    extends ConsumerState<_NotifPushPrefsSection> {
  NotificationPreferences? _local;

  Future<void> _update(NotificationPreferences next) async {
    setState(() => _local = next);
    await SettingsRepository.saveNotificationPreferences(next);
    ref.invalidate(notificationPreferencesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationPreferencesProvider);
    return async.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.amber),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (p) {
        _local ??= p;
        final prefs = _local!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('settings.notifPush.sectionTitle'.tr(),
                style:
                    AppTypography.label(size: 10, color: AppColors.mute)),
            const SizedBox(height: 8),
            _BoolTile(
              label: 'settings.notifPush.messages'.tr(),
              value: prefs.messages,
              onChanged: (v) => _update(prefs.copyWith(messages: v)),
            ),
            _BoolTile(
              label: 'settings.notifPush.interactions'.tr(),
              value: prefs.interactions,
              onChanged: (v) => _update(prefs.copyWith(interactions: v)),
            ),
            _BoolTile(
              label: 'settings.notifPush.zeitbank'.tr(),
              value: prefs.zeitbank,
              onChanged: (v) => _update(prefs.copyWith(zeitbank: v)),
            ),
            _BoolTile(
              label: 'settings.notifPush.crisis'.tr(),
              value: prefs.crisis,
              onChanged: (v) => _update(prefs.copyWith(crisis: v)),
            ),
            _BoolTile(
              label: 'settings.notifPush.marketing'.tr(),
              value: prefs.marketing,
              onChanged: (v) => _update(prefs.copyWith(marketing: v)),
            ),
          ],
        );
      },
    );
  }
}
