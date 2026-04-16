import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  bool _loading = false;

  @override void initState() { super.initState(); _loadProfile(); }
  @override void dispose() { _nameCtrl.dispose(); _nicknameCtrl.dispose(); _bioCtrl.dispose(); _locationCtrl.dispose(); _skillsCtrl.dispose(); super.dispose(); }

  Future<void> _loadProfile() async {
    final p = await ref.read(profileServiceProvider).getMyProfile();
    if (p != null && mounted) {
      _nameCtrl.text = p.name ?? '';
      _nicknameCtrl.text = p.nickname ?? '';
      _bioCtrl.text = p.bio ?? '';
      _locationCtrl.text = p.location ?? '';
      _skillsCtrl.text = p.skills.join(', ');
    }
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(profileServiceProvider).updateProfile(userId, {
        'name': _nameCtrl.text.trim(), 'nickname': _nicknameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(), 'location': _locationCtrl.text.trim(),
        'skills': _skillsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      });
      ref.invalidate(currentProfileProvider);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil gespeichert'))); context.pop(); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: \$e'))); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil bearbeiten'), actions: [
        TextButton(onPressed: _loading ? null : _save, child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Speichern')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 16),
        TextFormField(controller: _nicknameCtrl, decoration: const InputDecoration(labelText: 'Nickname')),
        const SizedBox(height: 16),
        TextFormField(controller: _bioCtrl, decoration: const InputDecoration(labelText: 'Bio'), maxLines: 3),
        const SizedBox(height: 16),
        TextFormField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Standort', prefixIcon: Icon(Icons.location_on_outlined))),
        const SizedBox(height: 16),
        TextFormField(controller: _skillsCtrl, decoration: const InputDecoration(labelText: 'Fähigkeiten (kommagetrennt)', prefixIcon: Icon(Icons.build_outlined))),
      ]),
    );
  }
}