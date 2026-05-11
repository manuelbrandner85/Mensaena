// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas, unused_import
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_modal.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/cinema_toggle.dart';
import '../../core/widgets/glow_button.dart';
import '../../services/supabase/auth_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = true;
  bool _publicProfile = true;
  bool _onlineStatus = true;
  bool _shareLocation = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _version = '${p.version}+${p.buildNumber}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.focus,
      appBar: const CinemaAppBar(title: 'EINSTELLUNGEN'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Section(title: 'Profil', children: [
              _SettingRow(
                icon: LucideIcons.user,
                label: 'Profil bearbeiten',
                description: 'Name, Bio, Ort, Avatar',
                trailing: const Icon(LucideIcons.chevronRight, color: MnColors.mute),
                onTap: () => GoRouter.of(context).push('/profile/me/edit'),
              ),
            ]),
            _Section(title: 'Benachrichtigungen', children: [
              _SettingRow(
                icon: LucideIcons.bell,
                label: 'Push-Benachrichtigungen',
                description: 'Aktiviert FCM auf diesem Geraet',
                trailing: CinemaToggle(
                  value: _pushEnabled,
                  onChanged: (v) => setState(() => _pushEnabled = v),
                ),
              ),
            ]),
            _Section(title: 'Datenschutz', children: [
              _SettingRow(
                icon: LucideIcons.shield,
                label: 'Profil oeffentlich',
                description: 'Andere koennen dein Profil sehen',
                trailing: CinemaToggle(
                  value: _publicProfile,
                  onChanged: (v) => setState(() => _publicProfile = v),
                ),
              ),
              _SettingRow(
                icon: LucideIcons.activity,
                label: 'Online-Status anzeigen',
                description: 'Andere sehen wann du aktiv bist',
                trailing: CinemaToggle(
                  value: _onlineStatus,
                  onChanged: (v) => setState(() => _onlineStatus = v),
                ),
              ),
              _SettingRow(
                icon: LucideIcons.mapPin,
                label: 'Standort teilen',
                description: 'Erlaubt Geo-Suche und Karte',
                trailing: CinemaToggle(
                  value: _shareLocation,
                  onChanged: (v) => setState(() => _shareLocation = v),
                ),
              ),
            ]),
            _Section(title: 'Konto', children: [
              _SettingRow(
                icon: LucideIcons.logOut,
                label: 'Abmelden',
                description: 'Beendet die aktuelle Session',
                onTap: _signOut,
              ),
              _SettingRow(
                icon: LucideIcons.trash2,
                label: 'Account loeschen',
                description: 'Unwiderruflich. Alle Daten werden entfernt.',
                onTap: _deleteAccount,
                accent: MnColors.herzrot,
              ),
            ]),
            _Section(title: 'Ueber Mensaena', children: [
              _SettingRow(
                icon: LucideIcons.info,
                label: 'Version',
                description: _version.isEmpty ? '...' : _version,
              ),
              _SettingRow(
                icon: LucideIcons.fileText,
                label: 'Datenschutz',
                onTap: () => GoRouter.of(context).push('/datenschutz'),
              ),
              _SettingRow(
                icon: LucideIcons.fileText,
                label: 'Impressum',
                onTap: () => GoRouter.of(context).push('/impressum'),
              ),
            ]),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Gemeinnuetzig. Werbefrei. Fuer immer.',
                style: MnTypography.body(color: MnColors.mute, size: 12),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await authService.signOut();
    if (!mounted) return;
    GoRouter.of(context).go('/auth');
  }

  Future<void> _deleteAccount() async {
    final confirm = await CinemaModal.show<bool>(
      context,
      title: 'Account loeschen?',
      child: Text(
        'Diese Aktion ist unwiderruflich. Alle deine Beitraege, Nachrichten und Bewertungen werden geloescht.',
        style: MnTypography.body(color: MnColors.inkSoft),
      ),
      actions: [
        GlowButton(
          label: 'Abbrechen',
          variant: GlowVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlowButton(
          label: 'Loeschen',
          variant: GlowVariant.crisis,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirm != true || !mounted) return;
    CinemaToast.show(
      context,
      variant: ToastVariant.warning,
      message: 'Bitte kontaktiere uns: info@mensaena.de',
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(title, style: MnTypography.label(color: MnColors.mute)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? accent;

  const _SettingRow({
    required this.icon,
    required this.label,
    this.description,
    this.trailing,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent ?? MnColors.teal;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MnColors.elevated,
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          border: Border.all(color: MnColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MnTypography.body(
                      color: accent ?? MnColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (description != null)
                    Text(
                      description!,
                      style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
