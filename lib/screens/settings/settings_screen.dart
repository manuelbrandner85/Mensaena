import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    _tabController = TabController(length: 6, vsync: this);
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
            Tab(text: 'Profil / Standort'),
            Tab(text: 'Benachrichtigungen'),
            Tab(text: 'Privatsphäre'),
            Tab(text: 'Sicherheit'),
            Tab(text: 'Barrierefreiheit'),
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
            _ProfileLocationSettings(settings: settings),
            _NotificationSettings(settings: settings),
            _PrivacySettings(settings: settings),
            const _SecuritySettings(),
            const _AccessibilitySettings(),
            const _AccountSettings(),
          ],
        ),
      ),
    );
  }
}

class _ProfileLocationSettings extends ConsumerStatefulWidget {
  final Map<String, dynamic> settings;
  const _ProfileLocationSettings({required this.settings});

  @override
  ConsumerState<_ProfileLocationSettings> createState() => _ProfileLocationSettingsState();
}

class _ProfileLocationSettingsState extends ConsumerState<_ProfileLocationSettings> {
  late TextEditingController _nameCtrl;
  late TextEditingController _nicknameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _postalCodeCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _homepageCtrl;
  String? _region;
  double _radius = 10;
  bool _saving = false;

  static const _regions = ['Wien', 'Niederösterreich', 'Oberösterreich', 'Salzburg', 'Tirol', 'Vorarlberg', 'Kärnten', 'Steiermark', 'Burgenland', 'Deutschland', 'Schweiz', 'Sonstige'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.settings['name'] as String? ?? '');
    _nicknameCtrl = TextEditingController(text: widget.settings['nickname'] as String? ?? '');
    _bioCtrl = TextEditingController(text: widget.settings['bio'] as String? ?? '');
    _locationCtrl = TextEditingController(text: widget.settings['location'] as String? ?? '');
    _addressCtrl = TextEditingController(text: widget.settings['address'] as String? ?? '');
    _cityCtrl = TextEditingController(text: widget.settings['home_city'] as String? ?? '');
    _postalCodeCtrl = TextEditingController(text: widget.settings['home_postal_code'] as String? ?? '');
    _phoneCtrl = TextEditingController(text: widget.settings['phone'] as String? ?? '');
    _homepageCtrl = TextEditingController(text: widget.settings['homepage'] as String? ?? '');
    _region = widget.settings['region'] as String?;
    _radius = (widget.settings['radius_km'] as num?)?.toDouble() ?? 10;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _postalCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _homepageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileServiceProvider).updateProfile(userId, {
        'name': _nameCtrl.text.trim(),
        'nickname': _nicknameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'home_city': _cityCtrl.text.trim(),
        'home_postal_code': _postalCodeCtrl.text.trim(),
        'region': _region,
        'phone': _phoneCtrl.text.trim(),
        'homepage': _homepageCtrl.text.trim(),
        'radius_km': _radius.round(),
      });
      ref.invalidate(settingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil gespeichert')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Profil & Standort', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nicknameCtrl,
          decoration: const InputDecoration(labelText: 'Benutzername', hintText: 'z. B. max_mustermann', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _bioCtrl,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(labelText: 'Adresse', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'Stadt', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _postalCodeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'PLZ', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _region,
          decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder()),
          items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setState(() => _region = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _locationCtrl,
          decoration: const InputDecoration(
            labelText: 'Standort (Anzeigename)',
            hintText: 'z. B. Wien, Mitte',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Radius', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_radius.round()} km', style: const TextStyle(color: AppColors.primary500, fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
          value: _radius,
          min: 1,
          max: 100,
          divisions: 99,
          label: '${_radius.round()} km',
          activeColor: AppColors.primary500,
          onChanged: (v) => setState(() => _radius = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _homepageCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Homepage',
            hintText: 'https://...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: const Text('Speichern'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
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
          subtitle: 'Benachrichtigungen auf dem Gerät',
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
          title: 'In der Nähe',
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
          subtitle: 'Andere können dein Profil sehen',
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
  const _SecuritySettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Sicherheit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.lock_outline, color: AppColors.primary500),
          title: const Text('Passwort ändern'),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
          contentPadding: EdgeInsets.zero,
          onTap: () => _showPasswordDialog(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.security_outlined, color: AppColors.primary500),
          title: const Text('Zwei-Faktor-Authentifizierung'),
          subtitle: const Text('Zusätzlicher Schutz für dein Konto'),
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

  void _showPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _newCtrl.text;
    if (pw.length < 8) {
      setState(() => _error = 'Passwort muss mind. 8 Zeichen haben');
      return;
    }
    if (pw != _confirmCtrl.text) {
      setState(() => _error = 'Passwörter stimmen nicht überein');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: pw));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwort geändert')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Fehler: $e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Passwort ändern'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _newCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Neues Passwort', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passwort bestätigen', border: OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Ändern'),
        ),
      ],
    );
  }
}

class _AccountSettings extends ConsumerWidget {
  const _AccountSettings();

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
                title: const Text('Konto löschen?'),
                content: const Text('Diese Aktion kann nicht rückgängig gemacht werden. Alle deine Daten werden unwiderruflich gelöscht.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Konto löschen'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
          label: const Text('Konto löschen', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

class _AccessibilitySettings extends StatefulWidget {
  const _AccessibilitySettings();

  @override
  State<_AccessibilitySettings> createState() => _AccessibilitySettingsState();
}

class _AccessibilitySettingsState extends State<_AccessibilitySettings> {
  double _fontSizeIndex = 1; // 0=small, 1=normal, 2=large
  bool _highContrast = false;
  bool _reduceAnimations = false;
  bool _loaded = false;

  static const _fontSizeLabels = ['Klein', 'Normal', 'Gross'];
  static const _prefFontSize = 'mensaena_font_size';
  static const _prefHighContrast = 'mensaena_high_contrast';
  static const _prefReduceAnimations = 'mensaena_reduce_animations';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontSizeIndex = (prefs.getInt(_prefFontSize) ?? 1).toDouble();
      _highContrast = prefs.getBool(_prefHighContrast) ?? false;
      _reduceAnimations = prefs.getBool(_prefReduceAnimations) ?? false;
      _loaded = true;
    });
  }

  Future<void> _saveFontSize(double value) async {
    setState(() => _fontSizeIndex = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefFontSize, value.round());
  }

  Future<void> _saveHighContrast(bool value) async {
    setState(() => _highContrast = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefHighContrast, value);
  }

  Future<void> _saveReduceAnimations(bool value) async {
    setState(() => _reduceAnimations = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefReduceAnimations, value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Barrierefreiheit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Passe die App an deine Bedürfnisse an.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),

        // Font size
        const Text('Schriftgrösse', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Ändere die Schriftgrösse in der App',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('A', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Expanded(
              child: Slider(
                value: _fontSizeIndex,
                min: 0,
                max: 2,
                divisions: 2,
                label: _fontSizeLabels[_fontSizeIndex.round()],
                activeColor: AppColors.primary500,
                onChanged: _saveFontSize,
              ),
            ),
            const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          ],
        ),
        Center(
          child: Text(
            _fontSizeLabels[_fontSizeIndex.round()],
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary500),
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),

        // High contrast
        SwitchListTile(
          title: const Text('Hoher Kontrast', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: const Text(
            'Erhöht den Kontrast für bessere Lesbarkeit',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          value: _highContrast,
          onChanged: _saveHighContrast,
          activeTrackColor: AppColors.primary500,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),

        // Reduce animations
        SwitchListTile(
          title: const Text('Animationen reduzieren', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: const Text(
            'Deaktiviert Übergangsanimationen und Bewegungseffekte',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          value: _reduceAnimations,
          onChanged: _saveReduceAnimations,
          activeTrackColor: AppColors.primary500,
          contentPadding: EdgeInsets.zero,
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
