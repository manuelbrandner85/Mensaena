import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// /dashboard/settings — Profil-Bearbeitung + Account-Aktionen.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();
  String? _avatarUrl;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _city.dispose();
    super.dispose();
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
          .select('name, bio, city, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      if (row != null) {
        _name.text = row['name'] as String? ?? '';
        _bio.text = row['bio'] as String? ?? '';
        _city.text = row['city'] as String? ?? '';
        _avatarUrl = row['avatar_url'] as String?;
      }
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      await db.from('profiles').update(<String, dynamic>{
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'city': _city.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil gespeichert')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
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
      final publicUrl = db.storage.from('avatars').getPublicUrl(path);
      await db.from('profiles').update(<String, dynamic>{
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      if (!mounted) return;
      setState(() => _avatarUrl = publicUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar aktualisiert')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(supabaseProvider).auth.signOut();
    if (!mounted) return;
    context.go(Routes.auth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Einstellungen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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
                            ? const Icon(Icons.person, size: 44, color: Colors.white)
                            : null,
                      ),
                      Material(
                        color: AppColors.primary500,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _uploadingAvatar
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Auf Kamera-Symbol tippen, um Avatar zu ändern',
                    style: TextStyle(color: AppColors.ink400, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 24),
                const _Label('Anzeigename'),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _deco(hint: 'Wie heißt du?'),
                ),
                const SizedBox(height: 12),
                const _Label('Bio'),
                TextField(
                  controller: _bio,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _deco(hint: 'Erzähl uns kurz von dir'),
                ),
                const SizedBox(height: 12),
                const _Label('Stadt'),
                TextField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: _deco(hint: 'z. B. Wien'),
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
                const Divider(height: 32),
                ListTile(
                  leading:
                      const Icon(Icons.logout, color: Color(0xFFB91C1C)),
                  title: const Text(
                    'Abmelden',
                    style: TextStyle(color: Color(0xFFB91C1C)),
                  ),
                  onTap: _logout,
                ),
              ],
            ),
    );
  }

  InputDecoration _deco({required String hint}) => InputDecoration(
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
