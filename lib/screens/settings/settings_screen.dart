import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('§ 09 · Konto'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary500,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary500,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Benachrichtigungen'),
            Tab(text: 'Privatsphäre'),
            Tab(text: 'Sicherheit'),
            Tab(text: 'Konto'),
          ],
        ),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (settings) => TabBarView(
          controller: _tabController,
          children: [
            _NotificationSettings(settings: settings),
            _PrivacySettings(settings: settings),
            _SecuritySettings(),
            _AccountSettings(),
          ],
        ),
      ),
    );
  }
}

class _NotificationSettings extends ConsumerWidget {
  final Map<String, dynamic> settings;
  const _NotificationSettings({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Benachrichtigungen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _SettingsSwitch(
          title: 'Push-Benachrichtigungen',
          subtitle: 'Benachrichtigungen auf dem Geraet',
          value: settings['notify_push'] as bool? ?? true,
          onChanged: (v) => _update(ref, 'notify_push', v),
        ),
        _SettingsSwitch(
          title: 'Nachrichten',
          subtitle: 'Bei neuen Direktnachrichten benachrichtigen',
          value: settings['notify_messages'] as bool? ?? true,
          onChanged: (v) => _update(ref, 'notify_messages', v),
        ),
        _SettingsSwitch(
          title: 'Interaktionen',
          subtitle: 'Wenn jemand Hilfe anbietet oder anfragt',
          value: settings['notify_interactions'] as bool? ?? true,
          onChanged: (v) => _update(ref, 'notify_interactions', v),
        ),
        _SettingsSwitch(
          title: 'In der Naehe',
          subtitle: 'Neue Beiträge in deiner Umgebung',
          value: settings['notify_nearby'] as bool? ?? true,
          onChanged: (v) => _update(ref, 'notify_nearby', v),
        ),
        _SettingsSwitch(
          title: 'System',
          subtitle: 'Wichtige Systemnachrichten',
          value: settings['notify_system'] as bool? ?? true,
          onChanged: (v) => _update(ref, 'notify_system', v),
        ),
      ],
    );
  }

  Future<void> _update(WidgetRef ref, String key, bool value) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(profileServiceProvider).updateProfile(userId, {key: value});
    ref.invalidate(settingsProvider);
  }
}

class _PrivacySettings extends ConsumerWidget {
  final Map<String, dynamic> settings;
  const _PrivacySettings({required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Privatsphäre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _SettingsSwitch(
          title: 'Öffentliches Profil',
          subtitle: 'Andere koennen dein Profil sehen',
          value: settings['profile_public'] as bool? ?? true,
          onChanged: (v) => _update(ref, 'profile_public', v),
        ),
        _SettingsSwitch(
          title: 'Standort anzeigen',
          subtitle: 'Deinen Standort auf der Karte zeigen',
          value: settings['show_location'] as bool? ?? true,
          onChanged: (v) => _update(ref, 'show_location', v),
        ),
        _SettingsSwitch(
          title: 'E-Mail anzeigen',
          subtitle: 'E-Mail-Adresse im Profil anzeigen',
          value: settings['show_email'] as bool? ?? false,
          onChanged: (v) => _update(ref, 'show_email', v),
        ),
        _SettingsSwitch(
          title: 'Telefon anzeigen',
          subtitle: 'Telefonnummer im Profil anzeigen',
          value: settings['show_phone'] as bool? ?? false,
          onChanged: (v) => _update(ref, 'show_phone', v),
        ),
      ],
    );
  }

  Future<void> _update(WidgetRef ref, String key, bool value) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(profileServiceProvider).updateProfile(userId, {key: value});
    ref.invalidate(settingsProvider);
  }
}

class _SecuritySettings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Sicherheit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.lock_outline, color: AppColors.primary500),
          title: const Text('Passwort aendern'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          contentPadding: EdgeInsets.zero,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Passwort-Aenderung wird per E-Mail gesendet')),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.security_outlined, color: AppColors.primary500),
          title: const Text('Zwei-Faktor-Authentifizierung'),
          subtitle: const Text('Zusaetzlicher Schutz fuer dein Konto'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          contentPadding: EdgeInsets.zero,
          onTap: () {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.devices_outlined, color: AppColors.primary500),
          title: const Text('Aktive Sitzungen'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          contentPadding: EdgeInsets.zero,
          onTap: () {},
        ),
      ],
    );
  }
}

class _AccountSettings extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Konto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.person_outline, color: AppColors.primary500),
          title: const Text('Profil bearbeiten'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          contentPadding: EdgeInsets.zero,
          onTap: () => context.push('/dashboard/profile/edit'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.download_outlined, color: AppColors.primary500),
          title: const Text('Daten exportieren'),
          subtitle: const Text('Deine Daten herunterladen'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          contentPadding: EdgeInsets.zero,
          onTap: () {},
        ),
        const Divider(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authServiceProvider).signOut();
            if (context.mounted) context.go('/auth/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Abmelden'),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Konto loeschen?'),
                content: const Text('Diese Aktion kann nicht rueckgaengig gemacht werden. Alle deine Daten werden unwiderruflich geloescht.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Konto loeschen'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
          label: const Text('Konto loeschen', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitch({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primary500,
      contentPadding: EdgeInsets.zero,
    );
  }
}
